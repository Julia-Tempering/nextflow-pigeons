#!/usr/bin/env Rscript
require("ggplot2")
require("dplyr")
require("scales")

data <- read.csv("aggregated/stats.csv.gz") %>%
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
    ylab("Time (s) for using Pigeons stmt") + 
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
  ggplot(aes(x = n_rounds, y = bytes, colour = date)) +
    ylab("Allocations (bytes)") + 
    xlab("Round") +
    geom_point()  + 
    theme_bw()
ggsave("allocations-by-round.pdf", width = 5, height = 5)
