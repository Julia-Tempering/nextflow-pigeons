#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")

data <- read.csv("aggregated/stats.csv.gz")
data %>%
  ggplot(aes(x = date, y = time)) +
    scale_y_log10() +
    ylab("Time (s)") + 
    xlab("Commit time") +
    geom_line()  + 
    theme_bw()
ggsave("times.pdf", width = 5, height = 5)
