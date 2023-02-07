deliverableDir = 'deliverables/' + workflow.scriptName.replace('.nf','')

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

  for commit in `git rev-list --remotes` 
  do
    echo \$commit > commit_\$commit
  done
  """
}

process make_private_julia { 
  time '1h'
  cpus 1
  echo false
  input:
    file repo_zip
    each commit
  output:
    file 'results' into results
  """
  mkdir private_julia 

  # prep repo
  cp $repo_zip private_julia/repo.zip
  cd private_julia
  unzip -q repo.zip
  cd repo
  mv $commit commit
  git reset --hard `cat commit`
  cd .. # back to private_julia
  
  # prep depot
  cp $depot_zip .
  unzip -q depot.zip
  mv .julia depot
  cd .. # back to task root

  export JULIA_DEPOT_PATH=`pwd`/private_julia/depot
  mkdir results
  julia -t 1 $benchmark_script
  """
}

process aggregate {
  time '1m'
  echo false
  scratch false
  input:
    file 'exec_*' from results.toList()
  output:
    file 'results/aggregated/' into aggregated
  """
  aggregate \
    --experimentConfigs.resultsHTMLPage false \
    --experimentConfigs.tabularWriter.compressed true \
    --dataPathInEachExecFolder stats.csv \
    --keys \
      commit \
           from info.tsv
  mv results/latest results/aggregated
  """
}

process plot {
  scratch false  
  publishDir deliverableDir, mode: 'copy', overwrite: true
   
  input:
    file aggregated
  output:
    file '*.*'
    file 'aggregated'   // include the csv files into deliverableDir
  afterScript 'rm Rplots.pdf; cp .command.sh rerun.sh'  // clean up after R, include script to rerun R code from CSVs
  """
  #!/usr/bin/env Rscript
  require("ggplot2")
  require("dplyr")
  
  data <- read.csv("${aggregated}/stats.csv.gz")
  data %>%
    ggplot(aes(x = date, y = time)) +
      scale_y_log10() +
      ylab("Time (s)") + 
      xlab("Commit time") +
      geom_line()  + 
      theme_bw()
  ggsave("times.pdf", width = 5, height = 5)
  """
  
}