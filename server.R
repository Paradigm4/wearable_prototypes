source("sleep.R")

shinyServer(function(input, output) {
  output$main_plot <- renderPlot({
    zoom = 10;
    if(input$zoom == "10 seconds")
    {
      zoom = 10
    }
    else if(input$zoom == "1 minute")
    {
      zoom = 60
    }
    else if (input$zoom == "2 minutes")
    {
      zoom = 120
    }
    else if (input$zoom == "1 hour")
    {
      zoom = 3600
    }
    else if (input$zoom == "2 hours")
    {
      zoom = 7200
    }
    else if (input$zoom == "10 hours")
    {
      zoom = 36000
    }
    else 
    {
      zoom = 86400
    }
    
    if(input$grid == "auto")
    {
      plot_data(input$subject, input$day, input$hour, input$minute, zoom,
               accelerometer=input$accelerometer,
               activity = input$activity,
               light = input$light,
               sleep = input$sleep,
               prediction = input$prediction)
    }
    else if(input$grid == "1 second")
    {
      plot_data(input$subject, input$day, input$hour, input$minute, zoom,
                accelerometer=input$accelerometer,
                activity = input$activity,
                light = input$light,
                sleep = input$sleep,
                prediction = input$prediction,
                grid_interval = 1000)
    }
    else if(input$grid == "10 seconds")
    {
      plot_data(input$subject, input$day, input$hour, input$minute, zoom,
                accelerometer=input$accelerometer,
                activity = input$activity,
                light = input$light,
                sleep = input$sleep,
                prediction = input$prediction,
                grid_interval = 10000)
    }
  })
})