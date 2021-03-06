#!/bin/bash

## script to run GATK for counting covariates before base quality recalibration

#PBS -l walltime=1:00:00
#PBS -l select=1:ncpus=1:mem=5gb

#PBS -M igf@imperial.ac.uk
#PBS -m ea
#PBS -j oe

#PBS -q pqcgi

# load modules
module load java/sun-jdk-1.6.0_19

NXTGENUTILS_HOME=/project/tgu/bin/nxtgen-utils-0.12.3

JAVA_XMX=4G

NOW="date +%Y-%m-%d%t%T%t"

POST_RECALIBRATION_REPORTS="recalibrationReports"
REFERENCE_FASTA=referenceFasta
MERGED_PRE_RECALIBRATION_REPORT=mergedPreRecalibrationReport
MERGED_POST_RECALIBRATION_REPORT=mergedPostRecalibrationReport
REALIGNED_RECALIBRATED_BAM=reaglignedRecalibratedBam
TARGET_INTERVALS_FILE=targetIntervals


echo "`${NOW}`copying merged pre-recalibration report to tmp directory..."
cp $MERGED_PRE_RECALIBRATION_REPORT $TMPDIR/merged_pre_recal_data.grp

echo "`${NOW}`copying chunk post-recalibration reports to tmp directory..."
INPUT_REPORT=""
REPORT_COUNT=0
for REPORT in $POST_RECALIBRATION_REPORTS; do
	
	REPORT_COUNT=$(( $REPORT_COUNT + 1 ))
	TMP_REPORT=$TMPDIR/in_report_$REPORT_COUNT	
	cp $REPORT $TMP_REPORT
    INPUT_REPORT="$INPUT_REPORT -i $TMP_REPORT"

done

#merge post-recalibration reports
echo "`${NOW}`merging recalibration reports..."
echo "`${NOW}`java -jar nxtgen-utils-0.12.3/NxtGenUtils.jar GatherGatkBqsrReports $INPUT_REPORT -o $TMPDIR/merged_recal_data.grp"
java -jar $NXTGENUTILS_HOME/NxtGenUtils.jar GatherGatkBqsrReports $INPUT_REPORT -o $TMPDIR/merged_post_recal_data.grp

echo "`${NOW}`copying merged recalibration report to $MERGED_RECALIBRATION_REPORT..."
cp $TMPDIR/merged_post_recal_data.grp $MERGED_POST_RECALIBRATION_REPORT

#analyse covariates from uncalibrated file


#analyse covariates from calibrated file


#calculate depth of coverage
echo "`${NOW}`copying re-aligned, recalibration BAM to tmp directory..."
BAM_NAME=`basename $REALIGNED_RECALIBRATED_BAM`
BAM_DIR=`dirname $REALIGNED_RECALIBRATED_BAM`
cp $REALIGNED_RECALIBRATED_BAM $TMPDIR/$BAM_NAME

echo "`${NOW}`calculating depth of coverage"
INTERVAL_ARG=""
if [ "$TARGET_INTERVALS_FILE" != targetIntervals ]
then
	INTERVAL_ARG="-L $TARGET_INTERVALS_FILE"
fi 

java -Xmx$JAVA_XMX -XX:+UseSerialGC -Djava.io.tmpdir=$TMPDIR -jar $GATK_HOME/GenomeAnalysisTK.jar \
  -T DepthOfCoverage \
  -R $REFERENCE_FASTA \
  -I $BAM_NAME \
  -o ${BAM_NAME}.coverage \
  -ct 2 -ct 4 -ct 10 -ct 20 -ct 30 \
  -mbq 20 \
  -mmq 20 \
  $INTERVAL_ARG

cp ${BAM_NAME}.coverage $BAM_DIR/

## would be good to add -geneList refSeq.sorted.txt , but need to generate this list first 
echo "`${NOW}`done"


