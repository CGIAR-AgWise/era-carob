library(data.table)
source("script/date_holds.R")
input <- list(Data.Out=data.frame(B.Code=c("A","B"),PD.Plant.Start=c(NA,"9999-01-01")))
holds <- data.table(table="Data.Out",field="PD.Plant.Start",merged_row=c("1","2"),
                    source_row=c("1","2"),
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

# Pin the complete ledger, not only its size or rows selected for a handoff.
contract <- list(rows=2L, canonical_sha256=date_hold_fingerprint(holds))
stopifnot(validate_date_hold_ledger(holds,contract),
          validate_date_hold_ledger(holds[2:1],contract),
          validate_date_hold_ledger(as.data.frame(holds),contract))
ledger_fails <- function(h) inherits(try(validate_date_hold_ledger(h,contract),silent=TRUE),"try-error")
stopifnot(ledger_fails(NULL), ledger_fails(holds[0]), ledger_fails(holds[1]),
          ledger_fails(rbind(holds[1],holds[1])),
          ledger_fails(copy(holds)[1,raw:="15/02/2005"]),
          ledger_fails(copy(holds)[1,status:="resolved"]),
          ledger_fails(copy(holds)[1,date:=""]),
          ledger_fails(copy(holds)[,source_row:=NULL]),
          ledger_fails(copy(holds)[,merged_row:=as.integer(merged_row)]))
cat("Complete ledger integrity checks passed, including lost and altered metadata.\n")
