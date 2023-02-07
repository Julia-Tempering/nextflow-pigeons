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

// TODO: list all commits and feed it down to make_private_julia

process make_private_julia { // will run one for each commit
  time '5m'
  cpus 1
  input:
    file repo_zip
  output:
    file 'private_julia' into private_julia
  """
  mkdir private_julia 

  # prep repo
  cp $repo_zip private_julia/repo.zip
  cd private_julia
  unzip repo.zip
  # TODO: switch to given commit
  # cd repo
  # git reset --hard COMMIT
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

/*

- list all commits across all branches

- copy zip file of .julia?

- unzip, 

- move to commit

Pkg.activate(".")
Pkg.offline()
Pkg.instantiate()


- run julia with provided julia home


*/