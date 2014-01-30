$c->{allow_web_signup} = 0;
$c->{allow_reset_password} = 0;

#disable export plugins



#disable default functionality
$c->{set_eprint_automatic_fields} = sub
{
	my ($eprint) = @_;
	my $repo = $eprint->repository;

	if ($eprint->is_set('parent_work_id'))
	{
		my $parent_work = $eprint->value('parent_work_id');
		$parent_work .= '/' . $eprint->value('parent_work_instance')
			if $eprint->is_set('parent_work_instance');
		$parent_work .= ', ' . $eprint->value('location_in_parent')
			if $eprint->is_set('location_in_parent');
		$eprint->set_value('parent_work', $parent_work);
	}

	if ($eprint->is_set('host_work_id'))
	{
		my $host_work = $eprint->value('host_work_id');
		$host_work .= '/' . $eprint->value('host_work_instance')
			if $eprint->is_set('host_work_instance');
		$host_work .= ', ' . $eprint->value('location_in_host')
			if $eprint->is_set('location_in_host');
		$eprint->set_value('host_work', $host_work);
	}

	if ($eprint->is_set('manuscript_id'))
	{
		my $manuscript_collocation = $eprint->value('manuscript_id');
		$manuscript_collocation .= ', ' . $eprint->value('manuscript_location')
			if ($eprint->is_set('manuscript_location'));
		$eprint->set_value('manuscript_collocation', $manuscript_collocation);
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
	my $ds = $work->dataset;

	my $search = $ds->prepare_search;
	$search->add_field(fields => [ $ds->field('parent_work_id') ], value => $work->value('work_id'));
	$search->add_field(fields => [ $ds->field('parent_work_instance') ], value => $work->value('instance_number'));
	my $list = $search->perform_search;
	my @refrain_arr = $search->perform_search->slice;

	my $refrains = {};
	foreach my $refrain (@refrain_arr)
	{

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

	my $host = $repo->call('instance_by_id', $repo, 'work', $work->value('host_work_id'), $work->value('host_work_instance'));
	if (!$host)
	{
		my $str = "Cannot load host for ";
		$str .= $work->value('work_id') . '/' . $work->value('instance_number');
		$repo->log($str);
	}

	return $host;
};

$c->{refrain_parent} = sub
{
	my ($refrain) = @_;
	my $repo = $refrain->repository;
	my $parent = $repo->call('instance_by_id', $repo, 'work', $refrain->value('parent_work_id'), $refrain->value('parent_work_instance'));

	if (!$parent)
	{
		my $str = "Cannot load parent for ";
		$str .= $refrain->value('refrain_id') . '/' . $refrain->value('instance_number');
		$repo->log($str);
	}

	return $parent;
};


#get an work or refrain instance
$c->{instance_by_id} = sub
{
	my ($repo, $type, $id, $instance) = @_;

	if (!$type || !$id || !$instance)
	{
		$type = 'UNDEF' unless $type;
		$id = 'UNDEF' unless $id;
		$instance = 'UNDEF' unless $instance;

		$repo->log("Part of instance details missing $type/$id/$instance");
		return undef; 
	}

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

	my $count = $list->count;
	if ($count != 1) #too many or not enough
	{
		$repo->log("ERR: Cannot locate instance: $type/$id/$instance") if !$count;
		if ($count)
		{
			my $ids = $list->ids;
			$repo->log("ERR: Found $count instances of: $type/$id/$instance: " . join(',',@{$ids})) if $count;
		}
		return undef;
	}

	my ($record) = $list->item(0); #get the first record (there should only be one)
	return $record;
};

