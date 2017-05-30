# wait until request is completed
# the loop stops when expr evaluates to TRUE
wait_for_azure <- function(expr, pause = 3, times = 40) {
  Sys.sleep(pause)
  terminate <- FALSE
  .counter <- 0
  while (!terminate && .counter <= times) {
    terminate <- isTRUE(eval(expr))
    if (terminate) break
    .counter <- .counter + 1
    Sys.sleep(pause)
  }
  terminate
}

# poll for status of provisiong a template
pollStatusTemplate <- function(azureActiveContext, deplname, resourceGroup) {
  message("Request Submitted: ", Sys.time())
  message("Key: A - accepted, (.) - waiting, U - updating, S - success, F - failure")
  iteration <- 0
  waiting <- TRUE
  while (iteration < 500 && waiting) {
    status <- azureDeployStatus(azureActiveContext, deplname = deplname, resourceGroup = resourceGroup)
    summary <- azureDeployStatusSummary(status)
    rc <- switch(tolower(summary),
        succeeded = "S",
        error = "F",
        failed = "F",
        running = ".",
        updating = "U",
        accepted = "A",
        "?"
      )

    message(rc, appendLF = FALSE)
    if (rc == "S") {
      waiting = FALSE
    }
    if (rc == "F") {
      message("F")
      warning(paste("Error deploying: ", Sys.time()))
      warning(fromJSON(status$properties$error$details$message)$error$message)
      return(FALSE)
    }
    if (rc == "?") message(status)

    iteration <- iteration + 1
    if (rc != "S") Sys.sleep(5)
    }
  return(TRUE)
}


# poll for status of provisiong a virtual machine
pollStatusVM <- function(azureActiveContext) {

  message("Request Submitted: ", Sys.time())
  message("Key: R - running, (.) - deallocating, D - deallocated, + - starting, S - stopped")
  iteration <- 0
  waiting <- TRUE
  while (iteration < 500 && waiting) {
    status <- azureVMStatus(azureActiveContext, ignore = "Y")
    summary <- gsub(".*?(deallocated|deallocating|running|updating|starting|stopped|NA).*?", "\\1", status)
    rc <- switch(tolower(summary),
      running = "R",
      deallocating = ".",
      deallocated = "D",
      updating = "U",
      starting = "+",
      stopped = "S",
      na = "X",
      "?"
      )

    message(rc, appendLF = FALSE)
    if (rc %in% c("S", "D", "X")) {
      waiting = FALSE
    }
    if (rc == "?") message(status)

    iteration <- iteration + 1
    if (!rc %in% c("S", "D", "X")) Sys.sleep(5)
    }
  message("")
  return(TRUE)
}

pollStatusHDI <- function(azureActiveContext, clustername) {

  message("HDI request submitted: ", Sys.time())
  message("Key: (.) - in progress, S - succeeded, E - error")
  iteration <- 0
  waiting <- TRUE
  while (iteration < 500 && waiting) {

    status <- azureListHDI(azureActiveContext, clustername = "*")
    status <- status[status$name == clustername, ]
    assert_that(nrow(status) == 1)
    summary <- status$provisioningState
    rc <- switch(tolower(summary),
      succeeded = "S",
      error = "E",
      inprogress = ".",
      "?"
      )

    message(rc, appendLF = FALSE)
    if (rc %in% c("S", "E")) {
      waiting = FALSE
    }
    if (rc == "E") {
      warning(paste("Error deploying: ", Sys.time()))
      warning(fromJSON(status$properties$error$details$message)$error$message)
      return(FALSE)
    }

    if (rc == "?") message(status)

    iteration <- iteration + 1
    if (!rc %in% c("S", "E")) Sys.sleep(10)
    }
  message("")
  message("HDI request completed: ", Sys.time())
  return(TRUE)
}