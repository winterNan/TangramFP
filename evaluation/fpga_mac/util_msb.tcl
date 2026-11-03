foreach d {f_syncmsb} {
 open_checkpoint $d/routed.dcp
 report_utilization -file $d/util.rpt
 close_design
}
