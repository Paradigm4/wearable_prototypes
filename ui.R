# BEGIN_COPYRIGHT
# 
# Copyright © 2014 Paradigm4, Inc.
# This App is used in conjunction with the Community Edition of SciDB.
# SciDB is free software: you can redistribute it and/or modify it under the terms of the Affero General Public License, version 3, as published by the Free Software Foundation.
#
# END_COPYRIGHT 

library(shiny)
library(scidb)

shinyUI(fluidPage(
  
  # Application title
  titlePanel("Sleep Data Demo"),
  
  # Sidebar with a slider input for the number of bins
  sidebarLayout(
    sidebarPanel(
      selectInput("subject", 
                  label = "Subject",
                  choices = c(1, 2, 3, 4, 5, 6, 7, 8),
                  selected = 2),
      sliderInput("day", "Day", min = 0, max=82, value=6, step=1),
      sliderInput("hour", "Hour", min=0, max=23, value=7, step=1),
      sliderInput("minute", "Minute", min=0, max=59, value=34, step=1),
      selectInput("zoom", label="Zoom", choices = c("10 seconds", "1 minute", "2 minutes", "1 hour", "2 hours", "10 hours", "whole day"),
                  selected = "2 hours"),
      selectInput("grid", 
                  label = "Grid Interval",
                  choices = c("auto", "1 second", "10 seconds"),
                  selected = "auto"),
      
      checkboxInput("accelerometer", "Accelerometer", TRUE),
      checkboxInput("activity", "Activity Score", FALSE),
      checkboxInput("light", "Light Sensor", FALSE),
      checkboxInput("sleep", "Actual Sleep", FALSE),
      checkboxInput("prediction", "Sleep Prediction", FALSE),
      width=3
    ),
    
    mainPanel(
      plotOutput(outputId = "main_plot", height="950px"),
      width=9
    )
  )
))