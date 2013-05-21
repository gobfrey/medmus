#!/usr/bin/perl

use strict;
use warnings;
use encoding qw(utf8);

use Text::CSV;

 my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();


my $filename = shift;
chomp($filename);

die "extract_works.pl *csv_file*\n" unless $filename;

open my $fh, "<:encoding(utf8)", $filename or die "$filename: $!";



my @rows;

while ( my $row = $csv->getline( $fh ) ) {
	push @rows, $row;
}
$csv->eof or $csv->error_diag();
close $fh;


my $records;

my $i = 1;
my $headings;
foreach my $row (@rows)
{
	if (!$headings)
	{
		$headings = $row;
	}
	else
	{
		my $r = hashify($headings, $row);

		my $record = {};

		#parent work cols
		foreach my $heading(
			'Occurance Type','Parent Work','Parent Index Blob','Parent Date','Parent vdB Index (rondeaux)',
			'Parent RS Index','Parent L Index','Parent T Index (songs)','Parent T Index (motets)',
			'Parent MW Index','Parent Lu Index','Parent Generic Descriptor','Parent Work Author'
		)
		{
			process_field($heading, $r, $record);
		}
		push @{$records}, $record if not_empty($record);
		$record->{csv_row} = $i;

		$record = {};
		#host work cols
		foreach my $heading(
			'Host Work','Host Work Date','Host Work Generic Descriptor','Host Work Author'
		)
		{
			process_field($heading, $r, $record);
		}
		push @{$records}, $record if not_empty($record);
		$record->{csv_row} = $i;
	}
	$i++;
}

merge_records($records);



use Data::Dumper;
print Dumper $records;


sub merge_records
{
	my ($records) = @_;

	my $merged_records = [];

	while (scalar @{$records})
	{
		my $current_record = pop @{$records};
		next unless defined $current_record;

		foreach my $i (0..$#{$records})
		{
			if (is_duplicate($current_record, $records->[$i]))
			{
				merge_in($current_record, $records->[$i]);
				$records->[$i] = undef;
			}
		}
	}
}

sub merge_in
{
	my ($master, $slave) = @_; #merge slave into master

	foreach my $k (keys %{$slave})
	{
		next if $k eq 'csv_row';

		if (!$master->{$k})
		{
#			$master->{$k} = $slave->{$k};
		}
		else
		{
			if (
				!ref $master->{$k} &&
				$master->{$k} ne $slave->{$k}
			)
			{
				print "Mismatch on $k (rows " . $master->{csv_row} . ' / ' . $slave->{csv_row} . ') : ';
				print $master->{$k} . ' /// ' . $slave->{$k} . "\n";
			}
			if (ref $master->{$k} eq 'ARRAY')
			{
				if (!arrays_same($master->{$k}, $slave->{$k}))
				{
					print "Mismatch on $k (rows " . $master->{csv_row} . ' / ' . $slave->{csv_row} . ') : ';
					print "[" . join(' // ',@{$master->{$k}}) . '] /// [' . join(' // ',@{$slave->{$k}}) . "]\n";
				}
			}
		}
	}
}


sub is_duplicate
{
	my ($r1, $r2) = @_;

	my $match_fields = [
		'Title',
		'vdB Index',
		'L Index',
		'Lu Index',
		'T Index (Songs)',
		'MW Index',
	];

	my $matches = {};
	my $mismatches = {};

	foreach my $k (@{$match_fields})
	{
		next unless (
			exists $r1->{$k} && $r1->{$k} &&
			exists $r2->{$k} && $r2->{$k}
		);
		if ($r1->{$k} eq $r2->{$k})
		{
			$matches->{$k}++;
		}
		else
		{
			$mismatches->{$k}++;
		}
	}

	if (scalar keys %{$matches}) #if there's at least one key in the hash
	{
		if (scalar keys %{$mismatches})
		{
			print "ID mismatch on spreadsheet (lines " . $r1->{csv_row} . " and " . $r2->{csv_row} . ")\n";
			print "\t Matched on [" . join(', ', keys %{$matches}) . "]\n";
			foreach my $k (keys %{$mismatches})
			{
				print "\t$k: " . $r1->{$k} . "\n";
				print "\t$k: " . $r2->{$k} . "\n";
			}

		}
		return 1;
	}

	return 0;
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


sub process_field
{
	my ($heading, $row, $record) = @_;

	return unless $row->{$heading} ne '';

	my $simple_cols = {
		'Occurance Type'		=> 'Type',
		'Parent Date'			=> 'Date',
		'Parent vdB Index (rondeaux)'	=> 'vdB Index',
		'Parent L Index'		=> 'L Index',
		'Parent T Index (songs)'	=> 'T Index (Songs)',
		'Parent MW Index'		=> 'MW Index',
		'Parent Generic Descriptor'	=> 'Generic Descriptor',
		'Host Work Date'		=> 'Date',
		'Host Work Generic Descriptor'	=> 'Generic Descriptor',
	};

	my $val = $row->{$heading};

	if ($simple_cols->{$heading})
	{
		$record->{$simple_cols->{$heading}} = $val;
	}

	elsif ($heading eq 'Host Work' || $heading eq 'Parent Work')
	{
		if ($val =~ m/\sv\../)
		{
			my $title = $`;
			$title =~ s/\s*$//g;

			$record->{'Title'} = $title;
		}
		else
		{
			$record->{'Title'} = $val;
		}
		$record->{'Title'} =~ s/\s+/ /g;
	}

	elsif ($heading eq 'Parent T Index (motets)')
	{
		my @vals = split(/\s*\/\s*/,$val);
		$record->{'T Index (Motets)'} = $val;
	}

	elsif ($heading eq 'Host Work Author' || $heading eq 'Parent Work Author')
	{
		my @vals = split(/\s*;\s*/,$val);
		$record->{'Authors'} = \@vals;
	}
	elsif ($heading eq 'Parent RS Index')
	{
		$val =~ s/^\s*//;
		if ($val =~ m/\s/)
		{
			my $index = $`;
			$record->{'RS Index'} = $index;
		}
		else
		{
			$record->{'RS Index'} = $val;
		}
	}
}

#do the arrays have the same content
sub arrays_same
{
	my ($arr1, $arr2) = @_;

	my $str1 = join('',sort(@{$arr1}));
	my $str2 = join('',sort(@{$arr2}));

	return $str1 eq $str2;	
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


