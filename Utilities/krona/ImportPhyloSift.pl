#! /usr/bin/perl

# Copyright © 2011, Battelle National Biodefense Institute (BNBI);
# all rights reserved. Authored by: Brian Ondov, Nicholas Bergman, and
# Adam Phillippy
#
# See the LICENSE.txt file included with this software for license information.


use strict;

# get the path of this script; dependencies are relative
#
my $scriptPath;
BEGIN
{
	use Cwd 'abs_path';
	abs_path($0) =~ /(.*)\//;
	$scriptPath = $1;
}
#use lib "$scriptPath/../lib";
use lib "$scriptPath/";

use Getopt::Long;
use Krona;

my $PHYLOSIFT_MIN_CONFIDENCE = 0.15;
my %TAXONOMIC_ORDERING = ( 
		"no rank" => 0,
		"domain" => 1,
		"superkingdom" => 1.9,
		"kingdom" => 2,
		"subkingdom" => 2.5,
		"superphylum" => 2.9,
		"phylum" => 3,
		"subphylum" => 3.5,
		"superclass" => 3.9,
		"class" => 4,
		"subclass" => 4.5,
		"superorder" => 4.9,
		"order" => 5,
		"suborder" => 5.5,
		"superfamily" => 5.9,
		"family" => 6,
		"subfamily" => 6.5,
		"supergenus" => 6.9,
		"genus" => 7.0,
		"subgenus" => 7.5,
		"superspecies" => 7.9,
		"species" => 8.5,
		"subspecies" => 9,
);
my $totalMag;
my $outFile = 'report.krona.html';
my $include;
my $random;
my $combine;
my $local;
my $verbose;

GetOptions(
	'o=s' => \$outFile,
	'i'   => \$include,
	'r'   => \$random,
	'c'   => \$combine,
	'l'   => \$local,
	'v'   => \$verbose
	);

if
(
	@ARGV < 1
)
{
 	print '

Description:
   Infers taxonomic abundance from PhyloSift results.  By default, each
   PhyloSift result file will create a separate dataset named after the file
   (see -c).

Usage:

ktImportBLAST [options] \
   phmmer_output_1[:magnitude_file_1] \
   phmmer_output_2[:magnitude_file_2] \
   ...

Input:

   blast_output     File containing BLAST results in tabular format ("Hit table
	                (text)" when downloading from NCBI).  If running BLAST
                    locally, subject IDs in the local database must contain GI
                    numbers in "gi|12345" format.
   
Options:

   [-o <string>]  Output file name.  Default is blast.krona.html.

   [-i]           Include queries with no hits in the total magnitude of the
                  chart.  If running BLAST locally, the output must have comment
                  lines ("-m 9") to use this option.

   [-r]           Break ties for the top hit randomly.  Default is to use the
                  lowest common ancestor of all ties for the top hit.

   [-p]           Color taxa by average percent identity instead of average log
                  e-value.

   [-b]           Color taxa by average bit score instead of average log
                  e-value.

   [-c]           Combine input files into single dataset.

   [-l]           Create a local chart, which does not require an internet
                  connection to view (but will only work on this computer).

   [-v]           Verbose.

';
	exit;
}

my %tree;

# load taxonomy

print "Loading taxonomy...\n";
loadTaxonomy();

# parse BLAST results

my $set = 0;
my @datasetNames;
my $zeroEVal;

foreach my $input (@ARGV)
{
	my $totalMagnitude;
	
	my ($fileName, $magFile, $taxonomicLevel) = split /:/, $input;
	
	$fileName =~ /([^\/]+)\./;
	
	if ( ! $combine )
	{
		push @datasetNames, $1;
	}
	
	my %magnitudes;
	
	# load magnitudes
	
	if ( defined $magFile )
	{
		print "Loading magnitudes for $fileName...\n";
		
		open MAG, "<$magFile" or die $!;
		
		while ( my $line = <MAG> )
		{
			chomp $line;
			my ( $id, $mag ) = split /\t/, $line;
			$magnitudes{$id} = $mag;
		}
		
		close MAG;
	}

        if ( ! defined $taxonomicLevel || length($taxonomicLevel) == 0)
        {
		$taxonomicLevel = "class"
        }
	
	print "Importing $fileName...\n";
	 
	open BLAST, "<$fileName";
        my $annotFile = $fileName;
        #print "$annotFile\n";
        $annotFile =~ s/hits/annots/;
        #print "$annotFile\n";
        open ANNOTS, ">$annotFile" or die $!;

	my $topScore;
	my $ties;
        my $taxID = undef;
        my $currCtg = undef;
	my $magnitude = 0;
        my %bestTaxa;
        my %bestScores;

	while ( 1 )
	{
		my $line = <BLAST>;
		
		chomp $line;
                #print "$line";
		my
		(
                        $contigID,
			$taxID,
                        $taxLevel,
			$taxaName,
			$score

		) = split /\t/, $line; #split /\t/, $line;
                if (!defined($contigID) || (defined($currCtg) && !($currCtg eq $contigID))) {
                   my $magnitude = 1;
                   if (defined($magnitudes{$currCtg})) {
                      $magnitude = $magnitudes{$currCtg}
                    }
                    # pick the best level to use
                    my $bestTaxon;
                    my $bestName;
                    my $printed = 0;

                    foreach my $taxa (keys %bestScores) {
                       print "$taxa\n";
                       if ($printed == 0 && $taxa eq $taxonomicLevel)
                       {
                           $printed = 1;
                           print ANNOTS "$currCtg\t$bestTaxa{$taxa}\n";
                       }

                       if ($bestScores{$taxa} > $PHYLOSIFT_MIN_CONFIDENCE) {
                          if (!defined($bestTaxon)) {
                             $bestTaxon = $bestTaxa{$taxa};
                             $bestName = $taxa;
                          } else {
                             if ($TAXONOMIC_ORDERING{$bestName} < $TAXONOMIC_ORDERING{$taxa}) {
                                   $bestTaxon = $bestTaxa{$taxa};
                                   $bestName = $taxa;
                        
                             }
                          }
                       }
                    }
                    add($set, \%tree, $bestTaxon, $magnitude, $bestScores{$bestName});
                    $totalMagnitude += $magnitude;
                    %bestScores = ();
                    %bestTaxa = ();
                }

                if ( ! defined $taxID )
                {
                        last; # EOF
                }
                if ( defined $taxID )
		{
                        if (!defined($bestScores{$taxLevel}) || $bestScores{$taxLevel} < $score) {
                           $bestScores{$taxLevel} = $score;
                           $bestTaxa{$taxLevel} = $taxID;
                        }
                        $currCtg = $contigID; 
		}
	}
	
	if ( $include && $totalMagnitude )
	{
		$tree{'magnitude'}[$set] = $totalMagnitude;
	}
	
	if ( ! $combine )
	{
		$set++;
	}
}

if ( $zeroEVal )
{
	print "\nWARNING: Couldn't take log for e-values of 0.  Used 1e-413.\n\n";
}

my @attributeNames =
(
	'taxon',
	'rank',
        'score',
	'magnitude'
);

my @attributeDisplayNames =
(
	'Taxon',
	'Rank',
        'Confidence',
	'Total'
);

print "Writing $outFile...\n";

writeTree
(
	\%tree,
	'Root',
	$outFile,
	$local,
	'magnitude',
	\@attributeNames,
	\@attributeDisplayNames,
	\@datasetNames,
        0,
        'score',
        0,
	1
);
