# == Class: icinga2
#
# This module installs and configures Icinga 2.
#
# === Parameters
#
# [*ensure*]
#   Manages if the service should be stopped or running. Defaults to running.
#
# [*enable*]
#   If set to true the Icinga 2 service will start on boot. Defaults to true.
#
# [*manage_repo*]
#   When set to true this module will install the packages.icinga.com repository. With this official repo you can get
#   the latest version of Icinga. When set to false the operating systems default will be used. As the Icinga Project
#   does not offer a Chocolatey repository, you will get a warning if you enable this parameter on Windows.
#   Defaults to false
#
# [*manage_service*]
#   If set to true the service is managed otherwise the service also
#   isn't restarted if a config file changed. Defaults to true.
#
# [*features*]
#   List of features to activate. Defaults to [checker, mainlog, notification].
#
# [*purge_features*]
#   Define if configuration files for features not managed by Puppet should be purged. Defaults to true.
#
# [*constants*]
#   Hash of constants. Defaults are set in the params class. Your settings will be merged with the defaults.
#
# [*plugins*]
#   A list of the ITL plugins to load. Defaults to [ 'plugins', 'plugins-contrib', 'windows-plugins', 'nscp' ].
#
# [*confd*]
#   This is the directory where Icinga 2 stores it's object configuration by default. To disable this, set the parameter
#   to false. It's also possible to assign your own directory. This directory is relative to etc/icinga2 and must be
#   managed outside of this module as file resource with tag icinga2::config::file. By default this parameter is true.
#
#
# All default parameters are set in the icinga2::params class. To get more technical information have a look into the
# params.pp manifest.
#
# === Variables
#
# [*_confd*]
#   Configuration directory (conf.d).
#
# [*_constants*]
#   Merge parameter constants with defaults from params.
#
# === Examples
#
# Declare icinga2 with all defaults. Keep in mind that your operating system may not have Icinga 2 in its package
# repository.
#
#  include ::icinga2
#
# If you want to use the official Icinga Project repository, enable the manage_repo parameter. Note: On Windows only
# chocolatey is supported as installation source. The Icinga Project does not offer a chocolatey repository, therefore
# you will get a warning if you enable this parameter
# on windows.
#
#  class { 'icinga2':
#    manage_repo => true,
#  }
#
# If you don't want to manage the Icinga 2 service with puppet, you can dissable this behaviour with the manage_service
# parameter. When set to false no service refreshes will be triggered.
#
#  class { 'icinga2':
#    manage_service => false,
#  }
#
# Sometimes it's necessary to cover very special configurations that you cannot handle with this module. In this case
# you can use the icinga2::config::file tag on your file resource. This module collects all file resource types with
# this tag and triggers a reload of Icinga 2 on a file change.
#
#  include ::icinga2
#  file { '/etc/icinga2/conf.d/foo.conf':
#    ensure => file,
#    owner  => icinga,
#    ...
#    tag    => 'icinga2::config::file',
#    ...
#  }
#
# To set constants in etc/icinga2/constants.conf use the constants parameter and as
# value a hash, every key will be set as constant and assigned by it's value. Defaults
# can be overwritten.
#
#  class { 'icinga2':
#    ...
#    constants   => {
#      'key1'             => 'value1',
#      'key2'             => 'value2',
#      'PluginContirbDir' => '/usr/local/nagios/plugins',
#    }
#  }
#
# The ITL contains several CheckCommand definitions to load, set these in the array
# of the plugins parameter, i.e. for a master or satellite do the following and
# disbale the load of the configuration in conf.d.
#
#  class { 'icinga':
#    ...
#    plugins => [ 'plugins', 'contrib-plugins', 'nscp', 'windows-plugins' ],
#    confd   => false,
#  }
#
# To use a different directory for your configuration, create the directory
# as file resource with tag icinga2::config::file.
#
#   file { '/etc/icinga2/local.d':
#     ensure => directory,
#     tag    => 'icinga2::config::file'
#   }
#   class { 'icinga2':
#     ...
#     confd => 'local.d',
#   }
#
#
class icinga2(
  $ensure         = running,
  $enable         = true,
  $manage_repo    = false,
  $manage_service = true,
  $features       = $icinga2::params::default_features,
  $purge_features = true,
  $constants      = {},
  $plugins        = $icinga2::params::plugins,
  $confd          = true,
) inherits ::icinga2::params {

  validate_re($ensure, [ '^running$', '^stopped$' ],
    "${ensure} isn't supported. Valid values are 'running' and 'stopped'.")
  validate_bool($enable)
  validate_bool($manage_repo)
  validate_bool($manage_service)
  validate_array($features)
  validate_bool($purge_features)
  validate_hash($constants)
  validate_array($plugins)

  # validate confd, boolean or string
  if is_bool($confd) {
    if $confd { $_confd = 'conf.d' } else { $_confd = undef }
  } elsif is_string($confd) {
    $_confd = $confd
  } else {
    fail('confd has to be a boolean or string')
  }

  # merge constants with defaults
  $_constants = merge($::icinga2::params::constants, $constants)

  anchor { '::icinga2::begin':
    notify => Class['::icinga2::service']
  }
  -> class { '::icinga2::repo': }
  -> class { '::icinga2::install': }
  -> File <| ensure == 'directory' and tag == 'icinga2::config::file' |>
  -> class { '::icinga2::config': notify => Class['::icinga2::service'] }
  -> Concat <| tag == 'icinga2::config::file' |>
  -> File <| ensure != 'directory' and tag == 'icinga2::config::file' |>
  ~> class { '::icinga2::service': }
  -> anchor { '::icinga2::end':
    subscribe => Class['::icinga2::config']
  }

  include prefix($features, '::icinga2::feature::')
}
