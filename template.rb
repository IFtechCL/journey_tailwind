=begin
Template Name: Kickoff - Tailwind CSS, Template Renamed as: Journey - Tailwind CSS
Author: Andy Leverenz <-- All credit to him.
Edited by: Pablo Blanco
Author URI: https://web-crunch.com, https://github.com/PabloB07
Instructions: $ rails new myapp -d <postgresql, mysql, sqlite3> -m template.rb
and finally: foreman start
=end

def source_paths
  [File.expand_path(File.dirname(__FILE__))]
end

def add_gems
  gem 'devise', '~> 4.7', '>= 4.7.3'
  gem 'friendly_id', '~> 5.4', '>= 5.4.1'
  gem 'sidekiq', '~> 6.1', '>= 6.1.2'
  gem 'name_of_person', '~> 1.1', '>= 1.1.1'
  gem 'omniauth'
  gem 'omniauth-twitter'
  gem 'font-awesome-rails'
end

def add_users
  # Install Devise
  generate "devise:install"

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'
  initializer "devise.rb" do
    "config.omniauth :twitter, Rails.application.credentials.fetch((:twitter_api_public), Rails.application.credentials.fetch(:twitter_api_secret)", :devise
  end

  insert_into_file "config/routes.rb",
    "devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }\n",
    after: "#{content}\n\n"

  route "root to: 'home#index'"

  # Create Devise User
  generate :devise, "User", "first_name", "last_name", "admin:boolean"

  # set admin boolean to false by default
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end
end

def copy_templates
  directory "app", force: true
end

def add_tailwind
  # Until PostCSS 8 ships with Webpacker/Rails we need to run this compatability version
  # See: https://tailwindcss.com/docs/installation#post-css-7-compatibility-build
  run "yarn add tailwindcss@npm:@tailwindcss/postcss7-compat postcss@^7 autoprefixer@^9"
  run "mkdir -p app/javascript/stylesheets"

  append_to_file("app/javascript/packs/application.js", 'import "stylesheets/application"')
  inject_into_file("./postcss.config.js", "\n    require('tailwindcss')('./app/javascript/stylesheets/tailwind.config.js'),", after: "plugins: [")

  run "mkdir -p app/javascript/stylesheets/components"
end

# Remove Application CSS
def remove_app_css
  remove_file "app/assets/stylesheets/application.css"
end

def add_sidekiq
  environment "config.active_job.queue_adapter = :sidekiq"

  insert_into_file "config/routes.rb",
    "require 'sidekiq/web'\n\n",
    before: "Rails.application.routes.draw do"

  content = <<-RUBY
    authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
    end
  RUBY
  insert_into_file "config/routes.rb", "#{content}\n\n", after: "Rails.application.routes.draw do\n"
end

def add_foreman
  copy_file "Procfile"
end

def add_friendly_id
  generate "friendly_id"
end

def add_omniauth
  generate  "omniauth" && "omniauth-twitter"
end

def add_font_awesome
  generate  "font-awesome-rails"
end

# Main setup
source_paths

add_gems

after_bundle do
  add_users
  remove_app_css
  add_sidekiq
  add_foreman
  copy_templates
  add_tailwind
  add_friendly_id
  add_omniauth
  add_font_awesome

  # Migrate & create a migration named add_omniauth_to_users
  rails_command "db:create"
  rails_command "db:migrate"
  rails_command "generate migration AddOmniauthToUsers provider:string uid:string"
  rails_command "db:migrate"

  git :init
  git add: "."
  git commit: %Q{ -m "Initial commit :fire: " }

  say
  say "Project successfully created, with this Template! 👍", :green
  say
  say "Switch to your app by running:"
  say "$ cd #{app_name}", :yellow
  say
  say "2 Ways to run:", :yellow
  say "$ rails server", :green
  say ""
  say "(foreman run web, sidekiq, webpacker services)", :yellow
  say "$ foreman start", :green
end
