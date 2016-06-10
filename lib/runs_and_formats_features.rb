module RunsAndFormatsFeatures

  MAX_LINE_LENGTH = 80
  H2P = File.expand_path(File.join(File.dirname(__FILE__), '../bin/h2p'))

  def normalise_line(line)
    return nil if line =~ /^Using the default profile/
    line = line.gsub(/\/Users\/matt/, '~')
    line = line.gsub(/\/Users\/ahellesoy/, '~')
    # line = line.gsub(/\dm\d\.\d\d\ds/, '0m0.003s') # TODO: Remove this before print for more real numbers.
    # Reproducible hex numbers (#to_s values)
    line = line.gsub(/0x[0-9a-f]*/, '0x63756b65') # Hex for 'cuke' :-)
    line = line.gsub(/~\/.rvm\/rubies\/ruby-[^\/]*\/bin\/ruby/, '/usr/bin/ruby')
    line = line.gsub(/~\/(projects|scm|github)\/(hwcuc_git|hwcuc|hwcuc2)\/Book\/code/, '~')

    # ServiceManager output (for message_queues chapter)
    line = line.gsub(/Server.*transaction_processor.*is up/, 'Server transaction_processor (94557) is up')
    line = line.gsub(/Server.*transaction_processor.*is shut down/, 'Server transaction_processor (94557) is shut down')
    line = line.gsub(/Shutting down.*transaction_processor.*/, 'Shutting down transaction_processor (94557)')
    line = line.gsub(/Starting.*transaction_processor.*with 'ruby lib\/transaction_processor.rb'/,
                     %{Starting transaction_processor in ~/message_queues/01 with\n  'ruby lib/transaction_processor.rb'})
  end

  def normalise_file(path)
    lines = IO.read(path).split("\n")
    out = lines.map { |line| normalise_line(line) }.flatten.compact.join("\n")
    File.open(path, "w") { |io| io.write(out) }
  end

  def output_for(feature_name, ext)
    feature_name.gsub(/\.feature$/, ext)
  end

  def run_features_in(path, options = {})
    Dir["#{path}/features/*.feature"].each do |feature|
      run_feature(feature, options)
    end
  end

  def run_feature(feature, options = {})
    project_dir = File.dirname(File.dirname(feature))
    puts project_dir

    cucumberansi = output_for(feature, '.cucumberansi')
    pmlcolor     = output_for(feature, '.pmlcolor')

    Dir.chdir(project_dir) do
      if File.exist?('bin/rails')
        `BUNDLE_GEMFILE=Gemfile bundle exec bin/rake db:migrate db:test:prepare`
      end

      if File.exist?('Gemfile')
        local_gemfile = 'Gemfile'
      else
        local_gemfile = ENV['BUNDLE_GEMFILE']
      end

      build_options = File.exists?('build_options') ? File.read('build_options').strip : ''
      ENV['CUCUMBER_TRUNCATE_OUTPUT'] = '74' # Cucumber will try to break lines that are longer than this
      pipe_to = if options[:exclude_stderr]
               '>'
             else
               '&>'
             end
      cmd = "BUNDLE_GEMFILE=#{local_gemfile} bundle exec cucumber #{build_options} --color features/#{File.basename(feature)} #{pipe_to} features/#{File.basename(cucumberansi)}"
      puts cmd
      `#{cmd}`

      normalise_file("features/#{File.basename(cucumberansi)}")

      cmd = "cat features/#{File.basename(cucumberansi)} | bundle exec a2h | #{H2P} > features/#{File.basename(pmlcolor)}"
      puts cmd
      `#{cmd}`
    end
    puts
  end

end
