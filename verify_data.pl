#!/usr/bin/perl -I/usr/share/eprints/perl_lib

use strict;
use warnings;

use EPrints;

my $repo_id = 'medmus';

my $repo = EPrints::Repository->new($repo_id);
die "Couldn't create repository: $repo_id\n" unless $repo;

my $seen = {};

$repo->dataset('eprint')->map(
	$repo, sub
	{
		my ($repo, $ds, $item) = @_;

		my $type = $item->value('medmus_type');

		if ($type eq 'refrain')
		{
			my $p = $repo->call('refrain_parent', $item); 

			my $id = $item->value('refrain_id');
			my $inst = $item->value('instance_number');
			if ($seen->{$id}->{$inst})
			{
				$repo->log("Duplicate ID: r$id/$inst"); 
			}
			$seen->{'r'}->{$id}->{$inst}++
		}
		elsif ($type eq 'work')
		{
			my $h = $repo->call('work_host', $item);
			#check we have at least one refrain or child work
			my $rs = $repo->call('refrains_in_work', $item);

			if (!$rs)
			{
				my $str = "No children for ";
				$str .= $item->value('work_id') . '/' . $item->value('instance_number');
				$repo->log($str);
				
			}

			my $id = $item->value('work_id');
			my $inst = $item->value('instance_number');
			if ($seen->{$id}->{$inst})
			{
				$repo->log("Duplicate ID: w$id/$inst"); 
			}
			$seen->{'w'}->{$id}->{$inst}++
		}
		else
		{
			$repo->loc("Item " . $item->value('id') . " has no type");
		}


		#count parent works


		#count host works


		#works - check we have at least one or work contained within

	}
);

