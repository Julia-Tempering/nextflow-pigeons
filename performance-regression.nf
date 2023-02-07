params.depot_zip
depot_zip = file(params.depot_zip)

benchmark_script = file("benchmark.jl")

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

  for commit in `git rev-list --remotes | head -n 1` 
  do
    echo \$commit > commit_\$commit
  done
  """
}


process make_private_julia { // will run one for each commit
  time '1h'
  cpus 1
  echo false
  input:
    file repo_zip
    each commit
  """
  mkdir private_julia 

  # prep repo
  cp $repo_zip private_julia/repo.zip
  cd private_julia
  unzip -q repo.zip
  cd repo
  git reset --hard `cat $commit`
  cd .. # back to private_julia
  
  # prep depot
  cp $depot_zip .
  unzip -q depot.zip
  mv .julia depot
  cd .. # back to task root

  export JULIA_DEPOT_PATH=`pwd`/private_julia/depot
  julia -t 1 $benchmark_script
  """
}


