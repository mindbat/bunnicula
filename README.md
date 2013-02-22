bunnicula
=========

Command-line tool for setting up new vhost apps

## Usage

Expects three parameters: name of the project, git repo url, and the domain name for the application.

For example:
    bunnicula.rb foo git@github.com:example/foo.git foo.example.com

Would setup a new virtual host for foo.example.com pointing to code checked out from git@github.com:example/foo.git into /var/www/foo

Run it as sudo.

## Dependencies

* Ubuntu
* Apache
* Ruby
* Git
* Mysql
* User named 'git' that has access to the repo url you give the script
* Mysql user named 'drupal'

## License

Distributed under the MIT License, the same as Rails.