#!/bin/bash

#
# script to run FastQC on a fastq file
# on cx1
#

#PBS -l walltime=24:00:00
#PBS -l select=1:ncpus=1:mem=500mb

#PBS -m ea
#PBS -M cgi@imperial.ac.uk
#PBS -j oe


module load fastqc/0.10.0

#now
NOW="date +%Y-%m-%d%t%T%t"

#today
TODAY=`date +%Y-%m-%d`

#CONFIGURATION
##############

#path to reads fastq file
PATH_READS_DIRECTORY=#pathReadsFastq
PATTERN_READ1=#patternRead1
PATTERN_READ2=#patternRead2

#QC output directory
PATH_QC_REPORT_DIR=#pathQcReportDir

#deployment
DEPLOYMENT_SERVER=#deploymentServer
DEPLOYMENT_PATH=#deploymentPath
SUMMARY_PATH=#summaryPath

#create temporary QC report output directory
mkdir $TMPDIR/qc

#for each read1 fastq file 
for FASTQ_READ1 in `ls --color=never $PATH_READS_DIRECTORY/*.f*q* | grep $PATTERN_READ1`
do
 
        FASTQ_READ1=`basename $FASTQ_READ1`

        #find read2 mate file
        FASTQ_READ2=""
	for FASTQ in `ls --color=never $PATH_READS_DIRECTORY/*.f*q* | grep $PATTERN_READ2`
	do	

	        FASTQ=`basename $FASTQ`
    		FASTQ_REPLACE=`echo $FASTQ | perl -pe "s/$PATTERN_READ2/$PATTERN_READ1/"`

    		if [ "$FASTQ_REPLACE" = "$FASTQ_READ1" ]; 
    		then
		        FASTQ_READ2=$FASTQ     
	    	fi

	done
             
        #check if mate file found and the number of lines in mate files is the same
	if [ -z $FASTQ_READ2 ]
	then
	        echo "ERROR:No mate file found for $FASTQ_READ1. Skipped."   		
	else

                gzip -t $PATH_READS_DIRECTORY/$FASTQ_READ1
                if [ $? -ne "0" ]
		then
	                echo "ERROR:File $FASTQ_READ1 is corrupted. Skipped." 
                else

                        gzip -t $PATH_READS_DIRECTORY/$FASTQ_READ2
                        if [ $? -ne "0" ]
		        then
	                        echo "ERROR:File $FASTQ_READ2 is corrupted. Skipped." 
                        else 

                                #copy fastqs to tmp space
                                echo "`${NOW}`copying fasq files to temporary scratch space..."
                                echo "`${NOW}`$FASTQ_READ1"
                                cp $PATH_READS_DIRECTORY/$FASTQ_READ1 $TMPDIR/$FASTQ_READ1

                                echo "`${NOW}`$FASTQ_READ2"
                                cp $PATH_READS_DIRECTORY/$FASTQ_READ2 $TMPDIR/$FASTQ_READ2

				#compare number of reads
                                COUNT_LINES_READ1=`gzip -d -c $TMPDIR/$FASTQ_READ1 | wc -l | cut -f 1 -d ' '`
                                COUNT_LINES_READ2=`gzip -d -c $TMPDIR/$FASTQ_READ2 | wc -l | cut -f 1 -d ' '`

                                if [ $COUNT_LINES_READ1 -ne $COUNT_LINES_READ2 ]
                                then
				        echo "ERROR:Unequal number of lines in the mate files. Skipped." 
				else

                                        #run FastQC 
                                        #--noextract   creating a zip archived report
                                        #--nogroup     disable grouping of bases for reads >50bp 

                                        echo "`${NOW}`running FastQC..."
                                        $FASTQC_HOME/fastqc -o $TMPDIR/qc --noextract --nogroup  $TMPDIR/$FASTQ_READ1
                                        $FASTQC_HOME/fastqc -o $TMPDIR/qc --noextract --nogroup  $TMPDIR/$FASTQ_READ2
	
                                fi	
                        fi
                fi
        fi  
done


#copy results to output folder
echo "`${NOW}`copying zipped QC report to $PATH_QC_REPORT_DIR..."
cp $TMPDIR/qc/*zip $PATH_QC_REPORT_DIR
chmod 660 $PATH_QC_REPORT_DIR/*zip

echo "`${NOW}`creating deployment directory $DEPLOYMENT_PATH on $DEPLOYMENT_SERVER..."
ssh $DEPLOYMENT_SERVER "mkdir -p -m 775 $DEPLOYMENT_PATH" > /dev/null 2>&1

for ZIP in `ls $TMPDIR/qc/*.zip`
do

        echo "`${NOW}`uncompressing QC report zip archive $ZIP..."
	unzip $ZIP
	REPORT_DIR=`basename $ZIP .zip`	
		
	echo "`${NOW}`deploying $REPORT_DIR report directory to $DEPLOYMENT_SERVER:$DEPLOYMENT_PATH..."
	scp -r $TMPDIR/$REPORT_DIR $DEPLOYMENT_SERVER:$DEPLOYMENT_PATH/  > /dev/null 2>&1
	ssh $DEPLOYMENT_SERVER "chmod 775 $DEPLOYMENT_PATH/$REPORT_DIR" > /dev/null 2>&1
	ssh $DEPLOYMENT_SERVER "chmod 775 $DEPLOYMENT_PATH/$REPORT_DIR/*"  > /dev/null 2>&1
	ssh $DEPLOYMENT_SERVER "chmod 664 $DEPLOYMENT_PATH/$REPORT_DIR/*/*"  > /dev/null 2>&1

        echo "`${NOW}`copying unzipped QC report to $PATH_QC_REPORT_DIR/$REPORT_DIR"
	mkdir -p -m 770 $PATH_QC_REPORT_DIR/$REPORT_DIR
	cp $TMPDIR/$REPORT_DIR/*.txt  $PATH_QC_REPORT_DIR/$REPORT_DIR
	chmod 660 $PATH_QC_REPORT_DIR/$REPORT_DIR/*.txt

done



  
