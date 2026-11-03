foreach d {f_std f_inmacnl f_inmac f_reg f_regnl f_sync f_syncrte f_regmsb f_regrte} {
 open_checkpoint $d/routed.dcp
 report_utilization -file $d/util.rpt
 close_design
}
