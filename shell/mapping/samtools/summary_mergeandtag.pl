#!/usr/bin/perl -w

$project_dir_analysis = "projectDirAnalysis";
$project_dir_results = "projectDirResults";
$date = "Today";
$project = "Project";
$deployment_server = "deploymentServer";
$summary_results = "summaryResults";
$summary_deployment = "summaryDeployment";
$sample_list = "sampleList";
$mark_duplicates = "markDuplicates";
$metric_level="metricLevel";
$collect_metric="collectMetric";
$url = "http://$deployment_server/$1" if $summary_deployment =~ /html\/(.*)/;
system("ssh $deployment_server mkdir $summary_deployment/pdf > /dev/null 2>&1");

%data = ();
$head = -1;
open (LIST, "$sample_list");
while (<LIST>){
    $head++;
    next unless $head;
    /^(\S+)\t(\S+)\t(\S+)\t/;
    $data{$2}{$3}{$1}++;
}

foreach $sample (keys %data){
    $log = "$project_dir_analysis/$date/$sample/samtoolsMergeAndTag.$sample.log";
    if (-s $log){
        foreach $library (keys %{$data{$sample}}){	
            if ("$mark_duplicates" eq "TRUE" ){
	        $dupmark = "$project_dir_results/$date/$sample/$sample"."_$library.dupmark.stats";
	        if (-s $dupmark){
                    $sum{$sample}{$library}{'0'}{'remove_dupl'} = "PASS";
	        }else{
                    $sum{$sample}{$library}{'0'}{'remove_dupl'} = "FAIL";
	        }
            }
        }

	$merge_sample_bam = "$project_dir_results/$date/$sample/$sample.bam";
	if (-s $merge_sample_bam){
            $sum{$sample}{'0'}{'0'}{'merge_sample'} = "PASS";
	}else{
            $sum{$sample}{'0'}{'0'}{'merge_sample'} = "FAIL";
	}  

        $sum{$sample}{'0'}{'0'}{'merge_sample'} = "FAIL" if `grep 'Number of reads before and after merging is not the same' $log`;

	$flagstat="$project_dir_results/$date/$sample/$sample".".bam.flagstat";
	open (FLAGSTAT, "$flagstat");
	while(<FLAGSTAT>){
	    $sum{$sample}{'0'}{'0'}{'total'} = $1 if /^(\d+) \+ \d+ in total \(/;
	    $sum{$sample}{'0'}{'0'}{'duplicates'} = $1 if /^(\d+) \+ \d+ duplicates$/;
	    $sum{$sample}{'0'}{'0'}{'mapped'} = $1 if /^(\d+) \+ \d+ mapped \(/;
	    $sum{$sample}{'0'}{'0'}{'paired'} = $1 if /^(\d+) \+ \d+ properly paired \(/;
	}

	$sum{$sample}{'0'}{'0'}{'duplicates_pct'} = ($sum{$sample}{'0'}{'0'}{'duplicates'}/$sum{$sample}{'0'}{'0'}{'total'})*100;
	$sum{$sample}{'0'}{'0'}{'mapped_pct'} = ($sum{$sample}{'0'}{'0'}{'mapped'}/$sum{$sample}{'0'}{'0'}{'total'})*100;
	$sum{$sample}{'0'}{'0'}{'paired_pct'} = ($sum{$sample}{'0'}{'0'}{'paired'}/$sum{$sample}{'0'}{'0'}{'total'})*100;
    }
}

open (OUT, ">$summary_results/index.html");
print OUT "<HTML>";
print OUT "<HEAD><META HTTP-EQUIV='refresh' CONTENT='60'></HEAD>";
print OUT "<BODY><TABLE CELLPADDING=5><TR>";
print OUT "<TH><CENTER>Sample<TH><CENTER>Library<TH>Read group";
print OUT "<TH><CENTER>Mark Duplicates" if ("$mark_duplicates" eq "TRUE");
print OUT "<TH><CENTER>Merge Bam";
print OUT "<TH>Total<BR>reads<TH>Duplicated<BR>reads<TH>Mapped<BR>reads<TH>Reads in<BR>concordant pairs";
print OUT "<TH>Sample<BR>metrics" if $metric_level =~ /S/;
print OUT "<TH>Library<BR>metrics" if $metric_level =~ /L/;
print OUT "<TH>Read group<BR>metrics" if $metric_level =~ /RG/;

foreach $sample (sort {$a cmp $b} keys %data){
    $log = "$project_dir_analysis/$date/$sample/samtoolsMergeAndTag.$sample.log";
    next unless (-s $log);
    print OUT "<TR><TD>$sample";
    $f1 = 1;
    foreach $library (sort {$a cmp $b} keys %{$data{$sample}}){
	print OUT "<TR><TD><TD>" unless $f1;
	print OUT "<TD>$library";
	$f2 = 1;
	foreach $read (sort {$a cmp $b} keys %{$data{$sample}{$library}}){
	    print OUT "<TR><TD><TD>" unless $f2;
	    print OUT "<TD>$read";
	    if ("$mark_duplicates" eq "TRUE"){
		if ($f2){
		    print OUT "<TD><CENTER><IMG SRC=tick.png ALT=PASS>" if $sum{$sample}{$library}{'0'}{'remove_dupl'} eq "PASS";
		    print OUT "<TD><CENTER><IMG SRC=error.png ALT=FAIL>" if $sum{$sample}{$library}{'0'}{'remove_dupl'} eq "FAIL";
		}else{
		    print OUT "<TD>";
		}
	    }

	    if ($f1){
		print OUT "<TD><CENTER><IMG SRC=tick.png ALT=PASS>" if $sum{$sample}{'0'}{'0'}{'merge_sample'} eq "PASS";
		print OUT "<TD><CENTER><IMG SRC=error.png ALT=FAIL>" if $sum{$sample}{'0'}{'0'}{'merge_sample'} eq "FAIL";
		print OUT "<TD><CENTER>$sum{$sample}{'0'}{'0'}{'total'}";
		printf OUT ("<TD><CENTER>$sum{$sample}{'0'}{'0'}{'duplicates'} (%.1f%%)", $sum{$sample}{'0'}{'0'}{'duplicates_pct'});
		printf OUT ("<TD><CENTER>$sum{$sample}{'0'}{'0'}{'mapped'} (%.1f%%)", $sum{$sample}{'0'}{'0'}{'mapped_pct'});
		printf OUT ("<TD><CENTER>$sum{$sample}{'0'}{'0'}{'paired'} (%.1f%%)", $sum{$sample}{'0'}{'0'}{'paired_pct'});
	    }else{
		print OUT "<TD><TD><TD><TD><TD>";
	    }

	    if ($metric_level =~ /S/){
		print OUT "<TD>";
		if ($f1){
		    foreach $ext (qw (gcBias insert_size_histogram quality_by_cycle quality_distribution)){
			$source = "$project_dir_results/$date/$sample/$sample".".$ext".".pdf";
			$destination = "$sample".".$ext".".pdf";
			system("scp -r $source $deployment_server:$summary_deployment/pdf/$destination > /dev/null 2>&1");
		        print OUT "<A HREF = '$url/pdf/$destination'>$ext</A><BR>";
		    }
		}
	    }

	    if ($metric_level =~ /L/){
		print OUT "<TD>";
		if ($f2){
		    foreach $ext (qw (gcBias insert_size_histogram)){
			$source = "$project_dir_results/$date/$sample/$sample"."_$library".".$ext".".pdf";
			$destination = "$sample"."_$library".".$ext".".pdf";
			system("scp -r $source $deployment_server:$summary_deployment/pdf/$destination > /dev/null 2>&1");
			print OUT "<A HREF = '$url/pdf/$destination'>$ext</A><BR>";
		    }
		}
	    }

            if ($metric_level =~ /RG/){
		print OUT "<TD>";
		foreach $ext (qw (quality_by_cycle quality_distribution)){
		    $source = "$project_dir_results/$date/$sample/$sample"."_$read".".$ext".".pdf";
		    $destination = "$sample"."_$read".".$ext".".pdf";
		    system("scp -r $source $deployment_server:$summary_deployment/pdf/$destination > /dev/null 2>&1");
		    print OUT "<A HREF = '$url/pdf/$destination'>$ext</A><BR>";
		}
	    }
	    $f1 = 0;
	    $f2 = 0;
        }
    }
}

print OUT "</TABLE>";

#deploying metrics

system("ssh $deployment_server mkdir $summary_deployment/metrics > /dev/null 2>&1");
$metrics_path = "$project_dir_results/$date/multisample";
$html_path = "$project_dir_analysis/$date/multisample";

if ($metric_level =~ /S/){
    print OUT "<HR><TABLE><TR><TD><FONT SIZE = '+1'>Alignment summary metrics";
    foreach $category (qw(FIRST_OF_PAIR SECOND_OF_PAIR PAIR)){
	$metrics_name = "$project.$date.alignment_summary_metrics.$category";
	$metrics_file = "$metrics_path/$metrics_name";
	$html_file = "$html_path/$metrics_name.php";
	if (-s $metrics_file){
	    system("scp -r $metrics_file $deployment_server:$summary_deployment/metrics/$metrics_name");
	    system("scp -r $html_file $deployment_server:$summary_deployment/metrics/$metrics_name.php");
	    print OUT "<TR><TD><TD><A HREF = '$url/metrics/$metrics_name.php'>$category</A>";
	}
    }
    print OUT "</FONT></TABLE><BR>";
}

if ($collect_metric =~ /TP/){
    $metrics_name = "$project.$date.targetedPcrMetrics";
    $metrics_file = "$metrics_path/$metrics_name";
    $html_file = "$html_path/$metrics_name.php";
    if (-s $metrics_file){
        system("scp -r $metrics_file $deployment_server:$summary_deployment/metrics/$metrics_name");
	system("scp -r $html_file $deployment_server:$summary_deployment/metrics/$metrics_name.php");
        print OUT "<P><FONT SIZE = '+1'><A HREF = '$url/metrics/$metrics_name.php'>Targeted PCR metrics</A></FONT><BR>";
    }
    $metrics_name = "$project.$date.perTargetCoverage";
    $metrics_file = "$metrics_path/$metrics_name";
    $html_file = "$html_path/$metrics_name.php";
    if (-s $metrics_file){
        system("scp -r $metrics_file $deployment_server:$summary_deployment/metrics/$metrics_name");
	system("scp -r $html_file $deployment_server:$summary_deployment/metrics/$metrics_name.php");
        print OUT "<P><FONT SIZE = '+1'><A HREF = '$url/metrics/$metrics_name.php'>Target coverage</A></FONT><BR>";
    }
}

if ($collect_metric =~ /HS/){
    $metrics_name = "$project.$date.hybridMetrics";
    $metrics_file = "$metrics_path/$metrics_name";
    $html_file = "$html_path/$metrics_name.php";
    if (-s $metrics_file){
        system("scp -r $metrics_file $deployment_server:$summary_deployment/metrics/$metrics_name");
	system("scp -r $html_file $deployment_server:$summary_deployment/metrics/$metrics_name.php");
        print OUT "<P><FONT SIZE = '+1'><A HREF = '$url/metrics/$metrics_name.php'>Hybrid metrics</A></FONT><BR>";
    }
    $metrics_name = "$project.$date.perTargetCoverage";
    $metrics_file = "$metrics_path/$metrics_name";
    $html_file = "$html_path/$metrics_name.php";
    if (-s $metrics_file){
        system("scp -r $metrics_file $deployment_server:$summary_deployment/metrics/$metrics_name");
	system("scp -r $html_file $deployment_server:$summary_deployment/metrics/$metrics_name.php");
        print OUT "<P><FONT SIZE = '+1'><A HREF = '$url/metrics/$metrics_name.php'>Target coverage</A></FONT><BR>";
    }
}

if ($collect_metric =~ /RS/){
    $metrics_name = "$project.$date.RnaSeqMetrics";
    $metrics_file = "$metrics_path/$metrics_name";
    $html_file = "$html_path/$metrics_name.php";
    if (-s $metrics_file){
        system("scp -r $metrics_file $deployment_server:$summary_deployment/metrics/$metrics_name");
	system("scp -r $html_file $deployment_server:$summary_deployment/metrics/$metrics_name.php");
        print OUT "<P><FONT SIZE = '+1'><A HREF = '$url/metrics/$metrics_name.php'>RNA-Seq metrics</A></FONT><BR>";
    }
    $chart_name = "$project.$date.chartOutput.pdf";
    $chart_file = "$metrics_path/$chart_name";
    if (-s $chart_file){
        system("scp -r $chart_file $deployment_server:$summary_deployment/metrics/$chart_name");
        print OUT "<P><FONT SIZE = '+1'><A HREF = '$url/metrics/$chart_name'>RNA integrity chart</A></FONT><BR>";
    }
}


print OUT "</BODY></HTML>";

system("scp -r $summary_results/index.html $deployment_server:$summary_deployment/index.html > /dev/null 2>&1");
system("ssh $deployment_server chmod 0664 $summary_deployment/* > /dev/null 2>&1");
system("ssh $deployment_server chmod 0664 $summary_deployment/pdf/* > /dev/null 2>&1");
system("ssh $deployment_server chmod -R 0775 $summary_deployment/pdf > /dev/null 2>&1");
system("ssh $deployment_server chmod -R 0775 $summary_deployment/metrics > /dev/null 2>&1");