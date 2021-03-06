#!/usr/bin/env Rscript
#
# ballgown_fpkmgenematrix.R 
#
#             using ballgown to compute gene-level differential expression matrix, and then
#             optionally make associated plots
# 
# Usage:
#     
# ./ballgown_fpkmgenematrix.R  --sample_dir_group_table <sample_group_table>            (required)
#                              --output_dir             <dir name>                      (required)
#                              --output_csvfile         <filename for diff exp matrix>  (required)
#                              --transcripts            <use transcripts instead>       (optional)
#                              --volcano_plot_file      <filename for volcano plot>     (optional)
#                                                       (only available if there are two condition groups)
#                              --variance_cutoff        <numeric>                       (optional, recommended: 1)
#
#                      planned, not yet implemented:
#                              --p_dist_plot_file 
#                              --q_dist_plot_file
#                              --fc_log                 <"linear","log2+1","log10+1">   (optional, default log2+1)
#                              --fc_threshold           <float>                         (optional, default 0)
#                              --q_val_threshold        <float>                         (optional, default 0)
#                             
#
# Example call:
#
# ./ballgown_fpkmgenematrix.R  --sample_dir_group_table samples_groups.txt --output_dir ballgown_out --output_csvfile testout.csv
#
#          samples_groups.txt contains lines of two columns 
#                                - sample subdirectory name (used as sample name
#                                - corresponding group (0, or 1)
#
#                example
#                         hy5_rep1_stringtie 0
#                         hy5_rep2_stringtie 0
#                         WT_rep1_stringtie  1
#                         WT_rep2_stringtie  1
#                (sub directory column can also have the full pathname specified)
#
#          testout.csv file is gene-level FPKM output 
#
#                example
#
#                         "id"	"fc"	"pval"	"qval"
#                         "AT1G01010"	1	NA	NA
#                         "AT1G01020"	1	NA	NA
#                         "AT1G01030"	1334.97985720067	0.440550490118355	0.787884152938117
#                         "AT1G01040"	0.190911435650667	0.181401258304825	0.787884152938117
#                         "AT1G01046"	1			NA			NA
#                         "AT1G01050"	1			NA			NA
#                         "AT1G01060"	0.293968217480655	0.212709415508708	0.787884152938117
#               
#           note that fold change "fc" values are only available when there's two condition groups.  
#           If there are more than two condition groups, this column will be populated by NA 
#

                         #############################
                         # Subroutines and functions #
                         #############################


dmesg <- function( msg, ... ) 
  { cat( "##################", msg, ..., "##################\n" ) }

get_and_check_samples_groups <- function( sgfile )     # load file which contains sample dir names and corresponding groups
  {
   # put in checks here:  directory existance, group validity, etc
   return( read.table( sgfile, col.names = c( "sample_dir", "group" ) ) )
  }



                              ################
                              # Main program #
                              ################

dmesg( "Hello this ballgown_fpkmgenematrix.R" )

dmesg( "getwd() is", getwd() )

suppressMessages( require("getopt") )
suppressMessages( require( ballgown ) )
suppressMessages( require( genefilter ) )   # for rowVars()

#suxppressMessages(require (rjson))

options( showWarnCalls = FALSE )
options( showErrorCalls = FALSE )

# parse command line arguments/options

option_tab = matrix( c(
                       'sample_dir_group_table', 's', 1, 'character',  # file containing table of sample_dir, group id (integer)
                       'output_dir',             'O', 1, 'character',  # where output file(s) go
                       'output_csvfile',         'o', 1, 'character',  # output differential gene expression CSV file name
                       'transcripts',            't', 0, 'logical',
                       'volcano_plot_file',      'V', 1, 'character',  # if given, generated volcano plot file of this name (png)
		       'variance_cutoff',        'c', 1, 'double',     # if specified apply variance cut value to genes to remove
                                                                       # those which don't show any variation before applying statistics
                       'p_dist_plot_file',       'Q', 1, 'character', 
                       'q_dist_plot_file',       'P', 1, 'character',
                       'fc_log',                 'L', 1, 'character',  # <"linear","log2+1","log10+1">   
                       'fc_threshold',           'f', 1, 'double',
                       'q_val_threshold',        'q', 1, 'double',
                       'help',                   'h', 0, 'logical'
                      ), 
                    byrow=TRUE, ncol=4 );

opt = getopt( option_tab )

if ( ! is.null( opt$help ) ) {
    dmesg( getopt( option_tab, usage=TRUE ) );
    q( status = 1 );
}
#dmesg( "ls -lR" )
#system( paste( "ls -lR", opt$input_dir ) ) 

dmesg( "Here is the option_tab matrix of arguments" )
print( option_tab )

dmesg( "about to get samples_groups table" )
smg <- get_and_check_samples_groups( opt$sample_dir_group_table )
print( smg )

ncond <- length( levels( as.factor( smg$group ) ) )
dmesg( "this contains", ncond, "condition groups" )


dmesg( "creating phenotype data frame for ballgown() constructor" )
pg <- data.frame( id    = basename( as.character( smg$sample_dir) ),
                  group = smg$group )
print( pg )

dmesg( "about to create ballgown" )
#bg <- ballgown( dataDir = opt$input_dir, samplePattern = opt$sample_dir_pat, meas="all" )
bg <- ballgown( samples = as.character( smg$sample_dir ),
                pData = pg,           
                verbose = TRUE,
                meas = "all" 
              )

dmesg( "here is bg str" )
print( str( bg ) )

dmesg( "here are sampleNames(bg)" )
print( sampleNames(bg) )

dmesg( "here is pData(bg)" )
print( pData(bg) )


#
# apply a low-variance cut 
# 
if ( is.null( opt$variance_cutoff ) ) {
    bgf <- bg
 } else {
    dmesg( paste( "applying a low-variance cut of", opt$variance_cutoff ) )
    bgf <- subset( bg, paste( "rowVars( texpr( bg ) ) >", opt$variance_cutoff),  genomesubset=TRUE )
 }

# create gene-level differential expression table
dmesg( "about to stattest" )

if (! is.null(opt$transcript)){
    diff_ex_tab <- stattest( bgf, feature='transcript', meas='FPKM', covariate='group',
                                  getFC = (ncond == 2) )
    diff_ex_tab$id = ballgown::transcriptNames(bgf)
} else {
    diff_ex_tab <- stattest( bgf, feature='gene', meas='FPKM', covariate='group', getFC = (ncond == 2) )
}

# for more than two conditions, we need to add in a column of NA for fold change to
# preserve the table format

if ( ncond > 2 ) {
   diff_ex_tab <- data.frame( feature = diff_ex_tab$feature,
                                   id = diff_ex_tab$id,
                                   fc = NA,
                                   pval = diff_ex_tab$pval,
                                   qval = diff_ex_tab$qval
                                 )
} else {
    diff_ex_tab$fc <- log2( diff_ex_tab$fc )
}

dmesg( "about to write.table" )

write.table( diff_ex_tab[,-1], 
             file=paste( opt$output_dir, opt$output_csvfile, sep="/"), 
             sep="\t", row.names=F )  # remove first column before saving

# If volcano_plot_file option is given, generate the plot and put
# it into the specified file
# (only available for two condition groups)

if ( ( ncond == 2 ) && ! is.null( opt$volcano_plot_file ) )
   {
    dmesg( paste( "creating volcano plot in", opt$volcano_plot_file ) )

    # todo -maybe we could check the extension in case the user wants a jpg?

    png( paste( opt$output_dir, opt$volcano_plot_file, sep="/" ) )

    plot( log2( diff_ex_tab$fc ), 
          -log10( diff_ex_tab$qval ), 
          pch=".", col="blue",
          xlab="log2( fold_change )",
          ylab="-log10( q-value )"
         )
    dev.off()
   }

dmesg( "Exiting ballgown_fpkmgenematrix.R" )

q( save="no" )     # don't bother saving the workspace

