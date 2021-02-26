require 'dependabot/file_fetchers'
require 'dependabot/file_parsers'
require 'dependabot/update_checkers'
require 'dependabot/file_updaters'
require 'dependabot/pull_request_creator'
require 'dependabot/omnibus'
require 'aws-sdk-codecommit'
require 'logger'
require 'fileutils'
require 'pry'

module DependabotCodecommit
  module Error
    class AlreadyUpToDate < StandardError
      def initialize(msg="Already up to date")
        super(msg)
      end
    end

    class UpdateNotPossible < StandardError
      def initialize(msg="Update not possible")
        super(msg)
      end
    end
  end

  class Runner
    # Communicate to dependabot-core GitHub repo
    #
    # repo_name:             CodeCommit repo name
    # base_path:             Base path to dependency file
    # branch:                CodeCommit branch
    # github_personal_token: Github Personal Access Token (read access to repo)
    # aws_region:            AWS Region of CodeComit eepo
    # package_managers:      List of package managers to run vulnerability checks against
    # aws_profile            AWS Profile name
    # log_file               Path to logfile
    def self.run repo_name:, base_path:, branch:, github_access_token:, aws_region:, package_managers:, aws_profile:, log_file:
      Aws.config.update region: aws_region, profile: aws_profile

      logfile_basepath = File.dirname log_file
      FileUtils.mkdir_p logfile_basepath

      logger = Logger.new(log_file)
      logger.level = :info
      logger.info '= run [START]'
      begin
        credentials = [{
          type: 'git_source',
          host: 'github.com',
          username: 'x-access-token',
          password: github_access_token
        }]

        source = self.source({
          logger: logger,
          aws_region: aws_region,
          repo_name: repo_name,
          base_path: base_path,
          branch: branch
        })

        package_managers.each do |package_manager|
          logger.info "processing: #{package_manager}"
          fetch_results = fetch_dependency_files({
            logger: logger,
            package_manager: package_manager,
            source: source,
            credentials: credentials
          })

          dependencies = self.parse_dependency_files({
            logger: logger,
            package_manager: package_manager,
            source: source,
            credentials: credentials,
            files: fetch_results[:files]
          })

          dependencies.select(&:top_level?).each do |dependency|
            begin
              updated_dependencies = self.check_for_updates({
                logger: logger,
                package_manager: package_manager,
                dependency: dependency,
                files: fetch_results[:files],
                credentials: credentials
              })
            rescue DependabotCodecommit::Error::UpdateNotPossible => err
              logger.error err.message
              next
            rescue DependabotCodecommit::Error::AlreadyUpToDate => err
              logger.error err.message
              next
            end
            updated_files = self.update_dependency_files({
              logger: logger,
              package_manager: package_manager,
              dependencies: updated_dependencies,
              files: fetch_results[:files],
              credentials: credentials
            })
            pull_request = self.create_pull_request({
              logger: logger,
              source: source,
              commit: fetch_results[:commit],
              dependencies: updated_dependencies,
              files: updated_files,
              credentials: credentials
            })
          end # dependencies.select
        end # package_managers.each
      rescue => err
        logger.error err.message
        err.backtrace.each do |line|
          logger.error line
        end
      end
    end

    # returns source
    def self.source logger:, aws_region:, repo_name:, base_path:, branch:
      logger.info 'source'
      Dependabot::Source.new({
        provider: 'codecommit',
        hostname: aws_region,
        repo: repo_name,
        directory: base_path,
        branch: branch
      })
    end

    # returns files and commit
    def self.fetch_dependency_files logger:, package_manager:, source:, credentials:
      logger.info 'fetch_dependency_files'
      fetcher = Dependabot::FileFetchers.for_package_manager(package_manager).new({
        source: source,
        credentials: credentials
      })
      fetcher.files.each do |file|
        logger.info "  fetcher.files: #{file.directory}#{file.name}"
      end
      logger.info "  fetcher.commit: #{fetcher.commit}"
      return {
        files: fetcher.files,
        commit: fetcher.commit
      }
    end

    # returns dependencies
    def self.parse_dependency_files logger:, package_manager:, source:, credentials:, files:
      logger.info 'parse_dependency_files'
      parser = Dependabot::FileParsers.for_package_manager(package_manager).new(
        dependency_files: files,
        source: source,
        credentials: credentials
      )
      dependencies = parser.parse
      dependencies.each do |dep|
        logger.info "  dependency: #{dep.package_manager} #{dep.name}##{dep.version}"
      end
      dependencies
    end

    # returns updated dependencies
    def self.check_for_updates logger:, package_manager:, dependency:, files:, credentials:
      logger.info "check_for_updates: #{dependency.package_manager} #{dependency.name}##{dependency.version}"
      checker = Dependabot::UpdateCheckers.for_package_manager(package_manager).new({
        dependency: dependency,
        dependency_files: files,
        credentials: credentials
      })

      raise DependabotCodecommit::Error::AlreadyUpToDate.new if checker.up_to_date?

      binding.pry
      requirements_to_unlock =
      if !checker.requirements_unlocked_or_can_be?
        if checker.can_update?(requirements_to_unlock: :none) then :none
        else :update_not_possible
        end
      elsif checker.can_update?(requirements_to_unlock: :own) then :own
      elsif checker.can_update?(requirements_to_unlock: :all) then :all
      else :update_not_possible
      end
      logger.info "  requirements_to_unlock: #{requirements_to_unlock}"

      raise DependabotCodecommit::Error::UpdateNotPossible.new if requirements_to_unlock == :update_not_possible

      checker.updated_dependencies({
        requirements_to_unlock: requirements_to_unlock
      })
    end

    # return updated_files
    def self.update_dependency_files logger:, package_manager:, dependencies:, files:, credentials:
      logger.info 'update_dependency_files'
      updater = Dependabot::FileUpdaters.for_package_manager(package_manager).new({
        dependencies: dependencies,
        dependency_files: files,
        credentials: credentials
      })
      updater.updated_dependency_files
    end

    # returns pull_request
    def self.create_pull_request logger:, source:, commit:, dependencies:, files:, credentials:
      logger.info 'create_pull_request'
      pr_creator = Dependabot::PullRequestCreator.new({
        source: source,
        base_commit: commit,
        dependencies: dependencies,
        files: files,
        credentials: credentials
      })
      pr_creator.create
    end
  end # class Runner
end # module DependabotCodecommit
