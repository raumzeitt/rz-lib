#!/usr/bin/perl -w
while (<>) {
    chomp;
    #if (/negedge/ and /(^.*posedge\s+\w+)(\s*\).*$)/) {
    if (/(^.*posedge\s+\w+)(\s*\).*$)/) {
        print "`ifdef RZ_LIB_ASYNC_RESETN\n";
        print "$1 or negedge resetn$2\n";
        print "\`else // RZ_LIB_ASYNC_RESETN\n";
        print "$_\n";
        print "\`endif // RZ_LIB_ASYNC_RESETN\n";
    } else {
        ; print "$_\n";
    }
}
