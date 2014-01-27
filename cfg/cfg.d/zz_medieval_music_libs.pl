$c->{allow_web_signup} = 0;
$c->{allow_reset_password} = 0;

#disable export plugins



#disable default functionality
$c->{set_eprint_automatic_fields} = sub
{
	my ($eprint) = @_;
	my $repo = $eprint->repository;

	if ($eprint->is_set('medmus_type') and $eprint->value('medmus_type') eq 'reading')
	{
		my $master_text = $eprint->value('reading_text');
		if (!$master_text)
		{
			my $texts = $eprint->value('reading_texts');
			$master_text = $texts->[0]->{text};
		}
		$eprint->set_value('master_text', $master_text);
	}
	if ($eprint->is_set('medmus_type') and $eprint->value('medmus_type') eq 'work')
	{
		#set manuscript
		my $manuscript_ids = {};

		my $refrains = $repo->call('refrains_in_work', $eprint);
		foreach my $r (@{$refrains})
		{
			$manuscript_ids->{$r->value('manuscript_id')}++;
		}
		$eprint->set_value('manuscript_id', join(' / ', keys %{$manuscript_ids}));
	}


};

#takes a work instance and returns an arrayref to the refrain instance(s) that appear in it
$c->{refrains_in_work} = sub
{
	my ($work, $depth) = @_;

	$depth = 1 unless $depth;
	return [] if $depth > 5; #safety -- remove loops (we shouldn't be going very deep anyway)

	my $repo = $work->repository;
	my $db = $repo->database;

	#quick and dirty mysql query (there are issues searching for compound multiple fields with the EPrints API)
	my $sql =
		'SELECT
			eprint_parent_work_id.eprintid
		FROM
			eprint_parent_work_id
			JOIN eprint_parent_work_instance
			ON
				eprint_parent_work_id.eprintid = eprint_parent_work_instance.eprintid
				AND eprint_parent_work_id.pos = eprint_parent_work_instance.pos
			JOIN eprint
			ON eprint.eprintid = eprint_parent_work_instance.eprintid
		WHERE
			eprint.medmus_type = "refrain" AND
			eprint_parent_work_instance.parent_work_instance = ' . $work->value('instance_number') . ' ' .
			'AND eprint_parent_work_id.parent_work_id = "' . $work->value('work_id') . '"';

	my $ds = $work->dataset;

	my $refrains = {};

	my $sth = $db->prepare_select($sql);
	$db->execute($sth, $sql);
	while (my $row = $sth->fetchrow_arrayref)
	{
		my $eprintid = $row->[0];
		my $refrain = $ds->dataobj($eprintid);

		$refrains->{$refrain->id} = $refrain; #into a hash for deduplication
	}

	#Is this a host work?  If so, recurse -- refrains will be grandchildren
	my $hosts = $repo->call('hosted_works', $work);

	if ($hosts) #empty arrayref will be fals
	{
		foreach my $host (@{$hosts})
		{
			my $host_refrains = $repo->call('refrains_in_work', $host, $depth+1);
			foreach my $r (@{$host_refrains})
			{
				$refrains->{$r->id} = $r; #in a has for deduplication reasons
			}
		}
	}
	my @vals = values %{$refrains};
	return [sort {$repo->call('refrain_sortval', $a) cmp $repo->call('refrain_sortval', $b)} @vals];
};


#create a sortable string from the refrain ID and the instance number with lots of zero padding
$c->{refrain_sortval} = sub
{
	my ($refrain) = @_;

	return sprintf("%8s%5s",$refrain->value('refrain_id'), $refrain->value('instance_number'));
};



#get all works that specify this as a host work
$c->{hosted_works} = sub
{
	my ($work) = @_;

	my $repo = $work->repository;
	my $ds = $repo->dataset('eprint');

	my $search = $ds->prepare_search;
	$search->add_field(fields => [ $ds->field('host_work_id') ], value => $work->value('work_id'));
	$search->add_field(fields => [ $ds->field('host_work_instance') ], value => $work->value('instance_number'));
	my $hosted_works = $search->perform_search;

	return [] unless $hosted_works->count;

	my @objs = $hosted_works->slice; #get all the records;
	return [ @objs ];
};

#get all objects sharing an ID (all instances within an ID)
$c->{all_instances} = sub
{
	my ($repo, $type, $id) = @_;

	my $ds = $repo->dataset('eprint');

	my $search = $ds->prepare_search();
#	$search->add_field(
#		fields => [ $ds->field('medmus_type') ],
#		value => $type,
#		match => 'EQ'
#	);
	$search->add_field(
		fields => [ $ds->field($type . '_id') ],
		value => $id,
		match => 'EQ'
	);

	my $list = $search->perform_search;

	return [] unless $list->count; #check that there's at least one result

	my @records = $list->slice(0,100); #100 should be enough...

	return [@records];
};



$c->{work_host} = sub
{
	my ($work) = @_;

	return undef unless $work->is_set('host_work_id');

	my $repo = $work->repository;

	return $repo->call('instance_by_id', $repo, 'work', $work->value('host_work_id'), $work->value('host_work_instance'));
};

$c->{refrain_parents} = sub
{
	my ($refrain) = @_;
	my $repo = $refrain->repository;

	my $parents_objs = [];
	my $parents = $refrain->value('parent_work');
	foreach my $parent (@{$parents})
	{
		my $parent_obj = $repo->call('instance_by_id', $repo, 'work', $parent->{id}, $parent->{instance});
		push @{$parents_objs}, $parent_obj if $parent_obj;
	}
	return $parents_objs;
};


#get an work or refrain instance
$c->{instance_by_id} = sub
{
	my ($repo, $type, $id, $instance) = @_;

	my $ds = $repo->dataset('eprint');

	my $search = $ds->prepare_search;
	$search->add_field(
		fields => [ $ds->field('medmus_type') ],
		value => $type,
		match => 'EQ'
	);
	$search->add_field(
		fields => [ $ds->field('instance_number') ],
		value => $instance,
		match => 'EQ'
	);

	$search->add_field(
		fields => [ $ds->field('work_id'), $ds->field('refrain_id') ],
		value => $id,
		match => 'EQ'
	);

	my $list = $search->perform_search;

	return undef unless $list->count; #check that there's at least one result

	my ($record) = $list->item(0); #get the first record (there should only be one)

	return $record;
};

