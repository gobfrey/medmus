#!/usr/bin/perl -I/usr/share/eprints/perl_lib

use strict;
use warnings;
use encoding qw(utf8);

use Text::CSV;

use EPrints;

my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();


my $filename = shift;
chomp($filename);

die "extract_refrains.pl *csv_file*\n" unless $filename;

open my $fh, "<:encoding(utf8)", $filename or die "$filename: $!";

my $ep = EPrints->new();
my $repo = $ep->repository( "medmus" );

die "unable to create repository object\n" unless $repo;

my $ds = $repo->dataset('archive');


my @rows;

while ( my $row = $csv->getline( $fh ) ) {
	push @rows, $row;
}
$csv->eof or $csv->error_diag();
close $fh;


my $records = extract_records(\@rows);

foreach my $record (@{$records})
{
	create_eprint_object($record);
}


sub create_eprint_object
{
	my ($record) = @_;	
	use Data::Dumper;


	my $refrain_epdata = refrain_to_epdata($record);
	print STDERR Dumper $refrain_epdata;

	foreach my $reading (@{$record->{readings}})
	{
		my $reading_epdata = reading_to_epdata($reading);

		my $dataobj = $ds->create_dataobj($reading_epdata);
		push @{$refrain_epdata->{readings}}, $dataobj->id;
	}

	my $refrain = $ds->create_dataobj($refrain_epdata);
}

sub refrain_to_epdata
{
	my ($record) = @_;

	my $epdata = { 'medmus_type' => 'refrain' };

	my $simple_mappings = {
		'Ref Number' => 'reference_number',
		'Abstract Master Text' => 'master_text',
	};

	foreach my $h (keys %{$simple_mappings})
	{
		$epdata->{$simple_mappings->{$h}} = $record->{$h} if ($record->{$h});
	}
	return $epdata;
}

sub reading_to_epdata
{
	my ($refrain) = @_;

	my $epdata = { 'medmus_type' => 'reading' };

	my $simple_mappings = {
		'Refrain Location' => 'location',
		'Singer' => 'singer',
		'Destinataire' => 'audience',
		'Circonstances' => 'circumstance',
		'Fonction' => 'function',
		'Marque de chant précédant le refrain' => 'preceeding_cue',
		'Marque de chant suivant le refrain' => 'succeeding_cue',
		'Marque de discours' => 'discourse',
		'Manuscript Collocation' => 'manuscript_collocation',
		'Métrique' => 'meter',
		'Other Manuscript Data' => 'other_data',
		'csv_row' => 'source_data_row',	
		'Reading' => 'source_data_reading_blob',
	};

	foreach my $h (keys %{$simple_mappings})
	{
		$epdata->{$simple_mappings->{$h}} = $refrain->{$h} if ($refrain->{$h});
	}

	if ($refrain->{'Derived Reading Text'} && $refrain->{'Derived Reading Text'} ne 'USERPROPERTY\\\\* MERGEFORMAT')
	{
		$epdata->{reading_text} = $refrain->{'Derived Reading Text'};
	}

	if ($refrain->{'Image File'})
	{
		my $path = $refrain->{'Image File'};

		$path =~ s/1_files/\/staves/;
		$epdata->{stave_image_rel_path} = $path;
	}

	my $simple_heading_mappings = {
		'Parent vdB Index (rondeaux)' => 'parent_vdb_index',
		'Parent L Index' => 'parent_l_index',
		'Parent T Index (songs)' => 'parent_t_index_songs',
		'Parent MW Index' => 'parent_mw_index',
		'Parent Lu Index' => 'parent_lu_index',
	}; 
	foreach my $h (keys %{$simple_heading_mappings})
	{
		$epdata->{$simple_heading_mappings->{$h}} = $refrain->{'Parent Refs'}->{$h} if ($refrain->{'Parent Refs'}->{$h});
	}

	if ($refrain->{'Parent Refs'}->{'Parent RS Index'})
	{
		my $val = $refrain->{'Parent Refs'}->{'Parent RS Index'};

		$val =~ s/^\s*//;
		if ($val =~ m/\s/)
		{
			my $index = $`;
			my $stanza = $';
			$epdata->{'parent_rs_index'} = $index;
			$epdata->{'parent_rs_index_stanza'} = $stanza
		}
		else
		{
			$epdata->{'parent_rs_index'} = $val;
		}
	}

	if ($refrain->{'Parent Refs'}->{'Parent T Index (motets)'})
	{
		my @vals = split(/\s*\/\s*/, $refrain->{'Parent Refs'}->{'Parent T Index (motets)'});
		$epdata->{'parent_t_indices'} = \@vals;
	}


	if ($refrain->{'Derived Reading Text Parts'})
	{
		foreach my $pos (keys %{$refrain->{'Derived Reading Text Parts'}})
		{
			push @{$epdata->{reading_texts}},
			{
				text => $refrain->{'Derived Reading Text Parts'}->{$pos},
				position => $pos,
			}
		}
	}

	return $epdata;
}


sub extract_records
{
	my ($rows) = @_;

	my $current_abstract_refrain; #used for creating child readings of each abstract refrain
	my $parent_ids = {};
	my $reading_data; #a number of columns (R and Y thru AE) should be repeated, but generally aren't

	my $i = 1;
	my $headings;
	foreach my $row (@{$rows})
	{
		if (!$headings)
		{
			$headings = $row;
		}
		else
		{
			my $r = hashify($headings, $row);

			if ($r->{'Ref Number'})
			{
				$current_abstract_refrain = {};
				foreach my $h ('Ref Number', 'Abstract Master Text')
				{
					$current_abstract_refrain->{$h} = $r->{$h};
				}
				$current_abstract_refrain->{readings} = [];
				push @{$records}, $current_abstract_refrain;
			}

			#new occurance, reset parent and reading data cache
			if ($r->{'Occurance Number'})
			{
				$parent_ids = {};
				foreach my $h (
					'Parent vdB Index (rondeaux)','Parent RS Index','Parent L Index','Parent T Index (songs)',
					'Parent T Index (motets)','Parent MW Index','Parent Lu Index',
				)
				{
					if ($r->{$h})
					{
						$parent_ids->{$h} = $r->{$h};
					}
				}

				$reading_data = {};
			}

			my $reading = {
				'Parent Refs' => $parent_ids
			};

			#Data might not be repeated across rows, but should be.  Inherit from previous values
			foreach my $h (
				'Refrain Location','Singer','Destinataire','Circonstances','Fonction',
				'Marque de chant précédant le refrain','Marque de chant suivant le refrain',
				'Marque de discours', 'Image File'
			)
			{
				if ($r->{$h})
				{
					$reading_data->{$h} = $r->{$h};
				}
				$reading->{$h} = $reading_data->{$h};
			}

			#parent work cols
			foreach my $h (
				'Manuscript Collocation','Reading',
				'Derived Reading Text','Métrique','Other Manuscript Data'
			)
			{
				$reading->{$h} = $r->{$h};
			}

			foreach my $h (
	'Derived Reading Text (Refrain 1 [sur l\'incipit français])',
	'Derived Reading Text (Refrain 1)','Derived Reading Text (Refrain 2)','Derived Reading Text (Refrain 3)',
	'Derived Reading Text (Refrain 4)','Derived Reading Text (Refrain 5)','Derived Reading Text (Refrain 6)',
	'Derived Reading Text (Refrain triplum)','Derived Reading Text (Refrain motetus)','Derived Reading Text (Refrain teneur)',
	'Derived Reading Text (Initial)','Derived Reading Text (Final)','Derived Reading Text (st. 1; refrain interne)',
	'Derived Reading Text (st. 1; refrain interne 2)','Derived Reading Text (st. 1; refrain final)',
	'Derived Reading Text (st. 2; refrain interne)','Derived Reading Text (st. 2; refrain interne 2)',
	'Derived Reading Text (st. 2; refrain final)','Derived Reading Text (st. 3; refrain interne)',
	'Derived Reading Text (st. 3; refrain interne 2)','Derived Reading Text (st. 3; refrain final)',
	'Derived Reading Text (st. 4; refrain interne)','Derived Reading Text (st. 4; refrain interne 2)',
	'Derived Reading Text (st. 4; refrain final)','Derived Reading Text (st. 5; refrain interne)',
	'Derived Reading Text (st. 5; refrain interne 2)','Derived Reading Text (st. 5; refrain final)',
	'Derived Reading Text (st. 6; refrain interne)','Derived Reading Text (st. 6; refrain interne 2)',
	'Derived Reading Text (st. 6; refrain final)','Derived Reading Text (st. 7; refrain interne)',
	'Derived Reading Text (st. 7; refrain interne 2)','Derived Reading Text (st. 7; refrain final)',
	'Derived Reading Text (st. 8; refrain interne)','Derived Reading Text (st. 8; refrain interne 2)',
	'Derived Reading Text (st. 8; refrain final)','Derived Reading Text (st. 9; refrain interne)',
	'Derived Reading Text (st. 9; refrain interne 2)','Derived Reading Text (st. 9; refrain final)',
	'Derived Reading Text (st. 10; refrain final)','Derived Reading Text (st. 11; refrain final)',
	'Derived Reading Text (st. 12; refrain final)','Derived Reading Text (st. 13; refrain final)',
	'Derived Reading Text (st. 14; refrain final)','Derived Reading Text (st. 15; refrain final)',
	'Derived Reading Text (st. 16; refrain final)','Derived Reading Text (st. 17; refrain final)',
	'Derived Reading Text (st. 18; refrain final)','Derived Reading Text (st. 19; refrain final)',
	'Derived Reading Text (st. 20; refrain final)','Derived Reading Text (st. 21; refrain final)',
	'Derived Reading Text (st. 22; refrain final)','Derived Reading Text (st. 23; refrain final)',
	'Derived Reading Text (st. 24; refrain final)','Derived Reading Text (st. 25; refrain final)',
	'Derived Reading Text (Envoi 1; refrain final)','Derived Reading Text (Envoi 2; refrain final)',
			)
			{
				next unless $r->{$h};

				$h =~m/\((.*)\)/;
				my $label = $1;
				$reading->{'Derived Reading Text Parts'}->{$1} = $r->{$h};
			}


			push @{$current_abstract_refrain->{readings}}, $reading if not_empty($reading);
			$reading->{csv_row} = $i;

		}
		$i++;
	}

	return $records;
}

sub not_empty
{
	my ($hashref) = @_;

	foreach my $v (values %{$hashref})
	{
		return 1 if $v;
	}
	return 0;
}

sub hashify
{
	my ($keys, $vals) = @_;

	use Data::Dumper;
	die "cannot hashify arrays of differing length\n" unless scalar @{$keys} == scalar @{$vals};

	my $hashref = {};
	foreach my $key ( @{$keys} )
	{
		$hashref->{$key} = shift @{$vals};
	}
	return $hashref;
}


