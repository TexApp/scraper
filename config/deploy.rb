require 'bundler/capistrano'

set :application, "texappscraper"

set :repository,  "git@github.com:texapp/scraper.git"
set :scm, :git
set :git_enable_submodules, 1

default_run_options[:pty] = true
set :user, 'scraper'
ssh_options[:forward_agent] = true
set :use_sudo, false

set :deploy_via, :remote_cache
set :deploy_to, "/var/scraper/"

role :app, "texapp.org"

namespace :deploy do
  task :symlink_credentials, :roles => :app do
    run "ln -nfs #{deploy_to}/shared/config/credentials.yml #{release_path}/config/credentials.yml"
  end
end

after 'deploy:update_code', 'deploy:symlink_credentials'
