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

process benchmark { 
  time '10m'
  cpus 1
  echo false 
  errorStrategy 'ignore'
  input:
    file repo_zip
    each commit
  output:
    file 'results' into results
  """
  # prep repo
  unzip -q repo.zip
  cd repo
    mv $commit commit
    git reset --hard `cat commit`
  cd .. 
  
  # prep depot
  cp $depot_zip .
  unzip -q depot.zip
  mv .julia depot

  export JULIA_DEPOT_PATH=`pwd`/depot
  mkdir results
  cd repo
    julia -t 1 $benchmark_script
    cp info.tsv ../results/info.tsv
    cp stats.csv ../results/stats.csv
  cd -
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
      date \
      in_master \
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
  require("scales")
  
  data <- read.csv("${aggregated}/stats.csv.gz") %>%
    mutate(date = as.POSIXct(date, origin="1970-01-01", tz="PT")) %>%
    mutate(time_per_expl = time / 10 / (2^n_rounds))

  data %>%
    filter(n_rounds == 10) %>%
    ggplot(aes(x = date, y = time_per_expl, colour = in_master)) +
      scale_y_log10() +
      scale_x_datetime(labels = date_format("%Y-%m-%d")) +
      ylab("Time (s) per exploration step") + 
      xlab("Commit date") +
      geom_point()  + 
      theme_bw()
  ggsave("times.pdf", width = 5, height = 5)

  data %>%
    filter(n_rounds == 0) %>%
    ggplot(aes(x = date, y = time_per_expl, colour = in_master)) +
      scale_y_log10() +
      scale_x_datetime(labels = date_format("%Y-%m-%d")) +
      ylab("Time (s) to load package") + 
      xlab("Commit date") +
      geom_point()  + 
      theme_bw()
  ggsave("times-using-stmt.pdf", width = 5, height = 5)

  data %>%
    filter(n_rounds == 10) %>%
    ggplot(aes(x = date, y = bytes, colour = in_master)) +
      scale_x_datetime(labels = date_format("%Y-%m-%d")) +
      ylab("Allocations for 10 rounds (bytes)") + 
      xlab("Commit date") +
      geom_point()  + 
      theme_bw()
  ggsave("allocations-by-commit.pdf", width = 5, height = 5)

  data %>%
    filter(n_rounds > 0) %>%
    ggplot(aes(x = n_rounds, y = bytes, colour = date)) +
      ylab("Allocations (bytes)") + 
      xlab("Round") +
      geom_point()  + 
      theme_bw()
  ggsave("allocations-by-round.pdf", width = 5, height = 5)

  """
  
}