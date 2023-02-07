params.depot_zip
depot_zip = file(params.depot_zip)

process clone { // clone only once
  executor 'local'
  cache true 

  output:
    file 'repo.zip' into repo_zip
  """
  git clone git@github.com:/Julia-Tempering/Pigeons.jl
  mv Pigeons.jl repo
  zip -r repo repo
  """
}

process list_commits {
  echo false
  input:
    file repo_zip 
  output:
    file 'repo/commit_*' into commit

  """
  unzip repo.zip
  cd repo 

  for commit in `git rev-list --remotes` 
  do
    echo \$commit > commit_\$commit
  done
  """
}

process temp {
  echo true 
  input:
    
  """
  echo Received: $commits
  """
}


process make_private_julia { // will run one for each commit
  time '5m'
  cpus 1
  input:
    file repo_zip
    each commit
  output:
    file 'private_julia' into private_julia
  """
  mkdir private_julia 

  # prep repo
  cp $repo_zip private_julia/repo.zip
  cd private_julia
  unzip repo.zip
  cd repo
  git reset --hard `cat $commit`
  cd -
  
  # prep depo
  cp $depot_zip private_julia/depot.zip
  cd private_julia
  unzip depot.zip
  mv .julia depot
  cd -
  """
}

process run_julia {
  echo true
  input:
    env JULIA_DEPOT_PATH from "private_julia/depot" 
    file private_julia
  """
  #!/usr/bin/env julia
  
  cd("private_julia/repo")

  using Pkg
  Pkg.offline()

  Pkg.activate(".")
  Pkg.instantiate()

  bench() = pigeons(target = toy_mvn_target(100), checkpoint = false, recorder_builders = [])
  
  function run_bench()
    bench()
    return @timed bench()
  end

  t = run_bench()

  # create CVS, order by branch
  """
}

