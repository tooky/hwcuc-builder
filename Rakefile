ROOTDIR = File.expand_path("..", __FILE__).sub(/#{Dir.pwd}(?=\/)/, ".")
LIBDIR  = File.join(ROOTDIR, "lib")
$LOAD_PATH.unshift LIBDIR if !$:.include?(LIBDIR)

BUILDDIR           = File.join(ROOTDIR, "working")
BUILD_GEMFILE      = File.join(BUILDDIR, "Gemfile")
BUILD_GEMFILE_LOCK = File.join(BUILDDIR, "Gemfile.lock")

CODE_DIR = File.join(ROOTDIR, "hwcuc-code")

BOOKDIR     = File.expand_path("hwcuc/Book", ROOTDIR)
BOOKCODEDIR = File.join(BOOKDIR, "code")

MASTER_GEMFILE      = File.join(BOOKDIR, "Gemfile")
MASTER_GEMFILE_LOCK = File.join(BOOKDIR, "Gemfile.lock")

require "runs_and_formats_features"

module Helpers
  def required(arg, args)
    return args[arg] if args[arg]
    fail "#{arg} is required"
  end

  def extract_revision(rev, to)
    Dir.chdir(CODE_DIR) do
      `git archive #{rev} | tar -x -C #{to}`
    end
  end

  def all_chapters(branch)
    `cd #{CODE_DIR} && git rev-list --grep="BOOK: begin-chapter" --pretty=format:"%s%n%b" #{branch} --reverse | grep "BOOK: begin-chapter" | sed 's/^BOOK: begin-chapter //'`.split
  end

  def chapter_start_refs(branch="HEAD")
    Dir.chdir(CODE_DIR) do
      `git rev-list --grep "^BOOK: begin-chapter" #{branch} --reverse`.split
    end
  end

  def chapter_start(name, branch="HEAD")
    Dir.chdir(CODE_DIR) do
      `git rev-list --grep "^BOOK: begin-chapter #{name}$" #{branch} --reverse`.chomp
    end
  end

  def chapter_end(name, branch="HEAD")
    start = chapter_start(name, branch)
    start_refs = chapter_start_refs(branch)
    next_start = start_refs[start_refs.index(start) + 1]
    return branch unless next_start

    Dir.chdir(CODE_DIR) do
      `git rev-parse --verify #{next_start}^`.chomp
    end
  end

  def clean_build_dir(name)
    rm_rf "#{BUILDDIR}/#{name}"
  end

  def range_condition(name, branch)
    ch_start = chapter_start(name, branch)
    ch_end = chapter_end(name, branch)

    if ch_start != ch_end
      %{--boundary ^#{ch_start} #{ch_end}}
    else
      %{#{ch_start}^!}
    end
  end

  def build_chapter(name, branch)
    clean_build_dir(name)
    mkdir "#{BUILDDIR}/#{name}"

    steps = Dir.chdir(CODE_DIR) do
      `git rev-list --reverse #{range_condition(name, branch)}`
    end.split.map { |r| r.gsub(/^-/, '') }

    steps.each.with_index(1) do |step_revision, step_number|
      working_dir = File.join(BUILDDIR, name, sprintf("%02d", step_number))
      mkdir working_dir
      extract_revision(step_revision, working_dir)
      run_features_in working_dir
    end
  end

  def deploy_chapter(name, branch)
    build_chapter(name, branch)

    chapter_build_dir = File.join(BUILDDIR, name)
    chapter_code_dir = File.join(BOOKCODEDIR, name)

    rm_rf chapter_code_dir
    cp_r chapter_build_dir, BOOKCODEDIR
  end
end

namespace :chapter do
  include Helpers
  include RunsAndFormatsFeatures

  desc "list chapters"
  task :list, [:branch] do |t, args|
    branch = args[:branch] || "HEAD"

    puts all_chapters(branch)
  end

  desc "show list of steps in a chapter"
  task :steps, :name, :branch do |t, args|
    name = required(:name, args)
    branch = args[:branch] || "HEAD"

    Dir.chdir(CODE_DIR) do
      puts `git rev-list --pretty=format:"%s" --reverse #{range_condition(name, branch)} | grep -v "^commit -\\?[0-9a-f]\\{40\\}$" | awk '{printf "%02d - %s\\n", NR, $0}'`
    end
  end

  directory BUILDDIR

  file BUILD_GEMFILE => [BUILDDIR, MASTER_GEMFILE] do
    cp MASTER_GEMFILE, BUILD_GEMFILE
  end

  file BUILD_GEMFILE_LOCK => [BUILD_GEMFILE, MASTER_GEMFILE_LOCK] do
    cp MASTER_GEMFILE_LOCK, BUILD_GEMFILE_LOCK
  end

  task :bundle => [BUILD_GEMFILE, BUILD_GEMFILE_LOCK] do
    `cd #{BUILDDIR} && BUNDLE_GEMFILE=#{BUILD_GEMFILE} bundle update`
  end

  desc "build output files"
  task :build, [:name, :branch] => :bundle do |t, args|
    name = required(:name, args)
    branch = args[:branch] || "HEAD"

    build_chapter(name, branch)
  end

  desc "deploy chapter to book"
  task :deploy, [:name, :branch] => :bundle do |t, args|
    name = required(:name, args)
    branch = args[:branch] || "HEAD"

    deploy_chapter(name, branch)
  end

  desc "deploy all chapters to book"
  task :"deploy:all", [:branch] => :bundle do |t, args|
    branch = args[:branch] || "HEAD"

    all_chapters(branch).each do |name|
      deploy_chapter(name, branch)
    end
  end

  desc "clean output files"
  task :clean, [:name] => :working do |t, args|
    name = required(:name, args)
    clean_build_dir(name)
  end
end
