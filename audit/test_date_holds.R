library(data.table)
source("script/date_holds.R")
input <- list(Data.Out=data.frame(B.Code=c("A","B"),PD.Plant.Start=c(NA,"9999-01-01")))
holds <- data.table(table="Data.Out",field="PD.Plant.Start",merged_row=c("1","2"),
                    B.Code=c("A","B"),raw=c("15/02/05","9999-01-01"),
                    date=c(NA_character_,"9999-01-01"),status=c("ambiguous_two_digit_year","unresolved_year"))
stopifnot(validate_date_holds(holds,input))
early <- copy(holds)[2]
early[,`:=`(raw="5-02-15",date="5-02-15")]
early_input <- input
early_input$Data.Out$PD.Plant.Start[2] <- "0005-02-15"
stopifnot(validate_date_holds(early,early_input),identical(early$date,"5-02-15"))
fails <- function(h) inherits(try(validate_date_holds(h,input),silent=TRUE),"try-error")
stopifnot(fails(copy(holds)[1,B.Code:="wrong"]),
          fails(copy(holds)[1,merged_row:="3"]),
          fails(copy(holds)[1,date:="2005-02-15"]),fails(rbind(holds,holds)))
cat("Date hold source identity and no-inference checks passed.\n")
