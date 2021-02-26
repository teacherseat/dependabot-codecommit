# DependabotCodeCommit

- This repo is a fork of [thegonch/dependabot-codecommit](https://github.com/thegonch/dependabot-codecommit])
- which is a fork of [dependabot/dependabot-script](https://github.com/dependabot/dependabot-script)

Why another fork?

- [x] package as ruby gem
- [x] separate CLI and SDK for separate use cases
- [x] refactor code into a stateless Plain Old Ruby Object (PORO)
- [x] replace optimist for standard library OptionParser
- [ ] add detailed logging
- [ ] add CloudFormation template to provision IAM Policy and AWS CodeBuild server
- [ ] create cool graphic
- [ ] write informative and opinionated Hashnode blog post


# Setup and usage

## Prerequisites

### Github Personal Access Token

You will need to provide a [Github Personal Access Token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) with full `repo` access.

Even though your repo is hosted in CodeCommit, Dependabot is a Github service so you need to authenicate via a github account.

### AWS Permissions

Create a new policy called `DependabotCodeCommitPolicy` with the
following permissions (update the Resource ARNS based on your requirements)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:ListPullRequests",
        "codecommit:BatchGetCommits",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetFile",
        "codecommit:GetFolder",
        "codecommit:GetPullRequest",
        "codecommit:GetRepository",
        "codecommit:CreateBranch",
        "codecommit:CreateCommit",
        "codecommit:CreatePullRequest"
      ]
      "Resource": [
        "arn:aws:codecommit:us-east-1:123456789012:myreponame"
      ]
    }
  ]
}
```

Attach this policy to the users or codebuild roles.

You want to use [aws-vault](https://github.com/99designs/aws-vault) to
secure your AWS Credentials in your local development environment.

## DependabotCodeCommit CLI

```
gem install dependabot-codecommit
dependabot-codecommit \ 
  --repo-name my_code_commit \
  --base_path '/' \
  --branch main \
  --github_access_token my-github-personal-access-token \
  --aws_region us-east-1 \
  --package_managers bundler,npm_and_yarn
```

## DependabotCodeCommit SDK

```rb
DependabotCodecommit::Runner.run({
  repo_name: 'my_codecommit_repo',
  base_path: '/',
  branch: 'main',
  github_access_token: 'my-github-personal-access-token',
  aws_region: 'us_east-1',
  package_managers: ['bundler','npm_and_yarn']
})
```

## DependabotCodeCommit Development

```
git clone git@github.com:teacherseat/dependabot-codecommit.git
cd dependabot-codecommit
bundle install
```

If you need to test the CLI locally

```
gem build dependabot-codecommit.gemspec
gem install --local dependabot-codecommit-1-0-0.gem
```

# Native helpers with `dependabot_helpers.sh`

The bash script [`dependabot_helpers.sh`][dependabot_helpers.sh] helps automate the installation of the Dependabot Native Helpers as described [here](https://github.com/dependabot/dependabot-script#native-helpers).

It is currently designed to install all possible native helpers, which includes:
Terraform, Python, Go (Dep & Modules), Elixir, PHP, JS

This also helps preserve your existing environment variables, including your `PATH`.
