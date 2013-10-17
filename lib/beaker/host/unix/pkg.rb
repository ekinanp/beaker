module Unix::Pkg
  include Beaker::CommandFactory

  def check_for_package(name)
    result = exec(Beaker::Command.new("which #{name}"), :acceptable_exit_codes => (0...127))
    case self['platform']
    when /solaris-10/
      result.stdout =~ %r|/.*/#{name}|
    else  
      result.exit_code == 0
    end
  end

  def install_package(name, cmdline_args = '')
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive in #{name}")
      when /el-4/
        @logger.debug("Package installation not supported on rhel4")
      when /fedora|centos|el-/
        execute("yum -y #{cmdline_args} install #{name}")
      when /ubuntu|debian/
        execute("apt-get update")
        execute("apt-get install #{cmdline_args} -y #{name}")
      when /solaris-11/
        execute("pkg #{cmdline_args} install #{name}")
      when /solaris-10/
        execute("pkgutil -i -y #{cmdline_args} #{name}")
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  def uninstall_package(name, cmdline_args = '')
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive rm #{name}")
      when /el-4/
        @logger.debug("Package uninstallation not supported on rhel4")
      when /fedora|centos|el-/
        execute("yum -y #{cmdline_args} remove #{name}")
      when /ubuntu|debian/
        execute("apt-get purge #{cmdline_args} -y #{name}")
      when /solaris-11/
        execute("pkg #{cmdline_args} uninstall #{name}")
      when /solaris-10/
        execute("pkgutil -r -y #{cmdline_args} #{name}")
      else
        raise "Package #{name} cannot be installed on #{self}"
    end
  end

  # Upgrade an installed package to the latest available version
  #
  # @param [String] name          The name of the package to update
  # @param [String] cmdline_args  Additional command line arguments for
  #                               the package manager
  def upgrade_package(name, cmdline_args = '')
    case self['platform']
      when /sles-/
        execute("zypper --non-interactive --no-gpg-checks up #{name}")
      when /el-4/
        @logger.debug("Package upgrade is not supported on rhel4")
      when /fedora|centos|el-/
        execute("yum -y #{cmdline_args} update #{name}")
      when /ubuntu|debian/
        execute("apt-get install -o Dpkg::Options::='--force-confold' #{cmdline_args} -y --force-yes #{name}")
      when /solaris-11/
        execute("pkg #{cmdline_args} update #{name}")
      when /solaris-10/
        execute("pkgutil -u -y #{cmdline_args} ${name}")
      else
        raise "Package #{name} cannot be upgraded on #{self}"
    end
  end
end
