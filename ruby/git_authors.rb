require 'open3'

# Define the Git command to get the list of modified files for a given branch
def modified_files_command(branch, base)
  "git diff --name-only #{base}..#{branch}"
end

# Define the Git command to get the author, additions, and deletions for a given file in a given branch
# @param [String] branch
# @param [String] file
# @param [String] base_branch
# @example {commit_sha_1: [line_range: [aututhor_1, ..., author_n], ...] commit_sha_2: [line_range: [aututhor_1, ..., author_n], ...]}
# return [Hash]
def file_stats_command(branch, file, base_branch)
  # 1. obtener los commits que modificaron el archivo
  commits = file_commits_on_branch(branch, base_branch, file)

  commits.each_with_object({}) do |commit, hash|
    # 2. a cada commit obtenemos la linea y rango modificados en cada commit
    modified_ranges = patch_stats_file(commit, file)
    # 3. obtener autor de commit con un git blame para la linea + el rango obtenido previamente
    # 4. se post procesa authores para quitar repetidos
    stats = modified_ranges.map { |s| Hash[s, previous_commit_authors(commit, s, file)] }
    hash[commit] = stats
  end
end

# Executes a git command and returns the stdout raw
# Also verifies if any error and raise a SystemExit error
#
# @param [String] command
# @raise [SystemExit]
# @return [String]
def execute_git_command(command)
  stdout, stderr, status = Open3.capture3(command)

  unless status.success?
    puts stderr
    raise SystemExit, 1
  end
  stdout
end

# Return all commits found for a file in a specific branch, related to a base branch
# @return [Array<String>]
def file_commits_on_branch(branch, base, file)
  command = "git log --pretty='%h' #{base}..#{branch} -- #{file}"

  stdout = execute_git_command(command)
  stdout.strip.split("\n")
end

# Returns an array for modified patches, on previos commits state with format [Line, amount lines]
#
# Example: for a file foo.rb an output could be ["120,3", 200,2]
# This means that line 120 has been modified on received `commit_sha` and used to had 3 lines
# @param [String] commit_sha commit to review
# @param [String] file filenemae to review
#
# @return [Array<String>]
def patch_stats_file(commit_sha, file)
  # get modified lines and rage based on each patch
  command = "git log -1 --patch #{commit_sha} -- #{file} | grep '^@@.*@@' | awk '{print $2}'"
  stdout = execute_git_command(command)

  stdout.strip.tr('-', '').split("\n")
end

# Returns an array of authors involved on previous commit on a specific range of lines
#
# @param [String] commit_sha current commit to check
# @param [String] line_range
def previous_commit_authors(commit_sha, line_range, file)
  command = "git blame #{commit_sha} -L #{line_range.gsub(',', ',+')} -- #{file} | awk '{print \$1}'"
  stdout = execute_git_command(command)

  commits = stdout.strip.split("\n").uniq
  commits.flat_map do |commit|
    command = "git log -1 #{commit} --pretty='%ce|%ae'"
    author = execute_git_command(command)
    author.strip.split('|')
  end.uniq
end

def update_hits_score(global_score, authors)
  authors.each do |a|
    if global_score.key?(a) # increases the gamer score
      global_score[a] += 1
    else
      global_score[a] = 1 # initialize a score for a new gamer
    end
  end
  global_score
end

begin
  global_score = {}
  total_commits = 0

  # Define the list of branches to process
  base = ARGV[0]
  branches = ARGV[1..]

  puts 'Procesando...'
  # Loop through each branch and print the stats for each modified file in that branch
  messages_by_branch = branches.each_with_object({}) do |branch, branch_hash|
    puts "#{branch} ...🦄"
    messages = []
    messages << ''
    messages << "Branch: #{branch}"
    messages << '============================='

    # Get the list of modified files for this branch
    stdout = execute_git_command(modified_files_command(branch, base))
    files = stdout.strip.split("\n")

    # Loop through each modified file and print the author and stats
    files.each do |file|
      stats = file_stats_command(branch, file, base)
      next if stats.empty?

      messages << "File: #{file}"
      stats.each do |commit, ranges|
        messages << "\t > Commit: #{commit}"
        ranges.each do |range|
          range.each do |line_range, authors|
            messages << "\t\tChanges on: #{file}:#{line_range}"
            messages << "\t\tAuthors: #{authors.join(' | ')}"

            global_score = update_hits_score(global_score, authors)
          end
        end
      end

      total_commits += stats.keys.size
    end
    branch_hash[branch] = messages
  end

  total_changes_in_patches = global_score.values.sum

  total_impact_by_contributor = global_score.each_with_object([]) do |(contributor, hits), arr|
    arr << Hash[contributor, (hits / total_changes_in_patches.to_f * 100.0).round(1)]
  end

  puts ''
  puts 'Summary'
  puts '============================='
  puts "Total commits: #{total_commits}"
  puts "Total changes: #{total_changes_in_patches}"
  puts ''
  total_impact_by_contributor.sort_by { |item| -item.values.first }.each do |impact|
    impact.each do |contributor, percentage|
      puts "\t#{contributor}: #{percentage}% of #{total_changes_in_patches} changes"
    end
  end

  verbose = false

  if verbose
    puts ''
    puts '============================='
    puts 'Branch data:'
    puts ''
    messages_by_branch.each do |_branch, messages|
      messages.each { |m| puts m }
    end
  end

  puts ''
end
