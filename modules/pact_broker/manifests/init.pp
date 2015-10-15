# == Class: pact_broker
#
# Sets up and runs the pact-broker application
#
# === Parameters
#
# [*port*]
#   The port the application should run on
#
# [*vhost*]
#   The vhost name to configure in nginx
#
# [*ssl_cert*]
#   The ssl certificate file to use (relative to /etc/ssl)
#
# [*ssl_key*]
#   The ssl key file to use (relative to /etc/ssl)
#
# [*user*]
#   The user to run the app as
#
# [*deploy_dir*]
#   Where to deploy and run the app from
#
# [*db_user*]
# [*db_password*]
# [*db_name*]
#   The database user, password and database name to use.
#
class pact_broker (
  $port = 3112,
  $vhost = 'pact-broker',
  $ssl_cert = 'certs/ssl-cert-snakeoil.pem',
  $ssl_key = 'private/ssl-cert-snakeoil.key',
  $user = 'pact_broker',
  $deploy_dir = '/srv/pact_broker',
  $db_user = 'pact_broker',
  $db_password,
  $db_name = 'pact_broker',
) {

  # vHost
  nginx::vhost::proxy  { $vhost:
    ssl           => true,
    ssl_redirect  => true,
    ssl_cert      => $ssl_cert,
    ssl_key       => $ssl_key,
    magic         => 'add_header Strict-Transport-Security "max-age=31536000";',
    upstream_port => $port,
  }

  # User
  user { $user:
    home       => $deploy_dir,
    managehome => true,
  }

  # Application
  class { 'pact_broker::app':
    app_root    => "${deploy_dir}/app",
    user        => $user,
    db_user     => $db_user,
    db_password => $db_password,
    db_name     => $db_name,
    require     => User[$user],
  }

  # Database
  postgresql::server::db { $db_name:
    user     => $db_user,
    password => $db_password,
  }

  # Service

  file { "${deploy_dir}/unicorn.rb":
    owner   => $user,
    mode    => '0644',
    content => template('pact_broker/unicorn.rb.erb'),
    notify  => Service['pact-broker'],
  }

  file { '/etc/init/pact-broker.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('pact_broker/upstart.conf.erb'),
    notify  => Service['pact-broker'],
  }

  file { '/etc/logrotate.d/pact_broker':
    source => 'puppet:///modules/pact_broker/logrotate',
    owner  => 'root',
    mode   => '0644',
  }

  service { 'pact-broker':
    ensure => running,
    enable => true,
  }

}
