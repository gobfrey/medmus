

$c->{medmus_render_reading_box} = sub
{
	my ($reading) = @_;

	my $repo = $reading->repository;
	my $xml = $repo->xml;
	my $frag = $xml->create_document_fragment;


	$frag->appendChild($repo->html_phrase('reading_box_heading_text'));
	if ($reading->is_set('reading_text'))
	{
		my $para = $xml->create_element('p');
		$frag->appendChild($para);
		$para->appendChild($reading->render_value('reading_text'));
	}
	if ($reading->is_set('reading_texts'))
	{
		$frag->appendChild($reading->render_value('reading_texts'));
	}	
#reading_text
#reading_texts
#stave_image_rel_path

	$frag->appendChild($repo->html_phrase('reading_box_heading_reading_metadata'));
	my $table = $xml->create_element('table');
	$frag->appendChild($table);

	foreach my $f ( qw/
manuscript_collocation
circumstance function discourse location
audience singer
preceding_cue succeeding_cue meter
other_data
	/ )
	{
		next unless $reading->is_set($f);
		$table->appendChild($repo->render_row($repo->html_phrase('eprint_fieldname_' . $f), $reading->render_value($f)));
	}

	$frag->appendChild($repo->html_phrase('reading_box_heading_parent_metadata'));
	$table = $xml->create_element('table');
	$frag->appendChild($table);

	foreach my $f ( qw/
parent_l_index
parent_lu_index
parent_mw_index
parent_rs_index
parent_rs_index_stanza
parent_t_index_songs
parent_t_indices
parent_vdb_index
	/ )
	{
		next unless $reading->is_set($f);
		$table->appendChild($repo->render_row($repo->html_phrase('eprint_fieldname_' . $f), $reading->render_value($f)));
	}

	return $frag;
};

$c->{work_summary_page_metadata} = [qw(
work_id
title
generic_descriptor
number_of_parts
voice_in_polyphony
primary_language
secondary_language
style_of_discourse
number_of_stanzas
number_of_envois
date_description
authors
l_index
mw_index
rs_index
t_index_motets
t_index_songs
lu_index
vdb_index
host_works
other_data
edition
)];

$c->{medmus_render_work} = sub
{
	my ($work) = @_;

	my $repo = $work->repository;
	my $xml = $repo->xml;
	my $frag = $xml->create_document_fragment;

	my $div = $xml->create_element('div');
	$frag->appendChild($div);

	$div->appendChild($work->render_citation('work_summary'));

	return $frag;
};

$c->{medmus_render_refrain} = sub
{
	my ($refrain, $readingid_to_highlight) = @_;

	my $repo = $refrain->repository;
	my $xml = $repo->xml;
	my $frag = $xml->create_document_fragment;

	my $div = $xml->create_element('div');
	$frag->appendChild($div);
	$div->appendChild($repo->html_phrase('eprint_fieldname_reference_number'));
	$div->appendChild($xml->create_text_node(': '));
	$div->appendChild($refrain->render_value('reference_number'));

	my $h3 = $xml->create_element('h3');
	$frag->appendChild($h3);
	$h3->appendChild($repo->html_phrase('refrain_abstract_readings_heading'));

	my $reading_ids = $refrain->value('readings');

	foreach my $id (@{$reading_ids})
	{
		my $reading = $repo->eprint($id);

		my %box_args = (
			'title' => $reading->render_citation('brief'),
			'content' => $repo->call('medmus_render_reading_box', $reading),
			'id' => 'medmus_reading_box_' . $id,
			'session' => $repo,
			'collapsed' => 1,
		);

		if ($readingid_to_highlight == $id)
		{
			$box_args{collapsed} = 0;
		}


		$frag->appendChild(EPrints::Box::render(%box_args));
	}


	return $frag;
};

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

	#Does this work have a host work?  If so, recurse refrains will be grandchildren
	if ($work->is_set('host_work_id'))
	{
		my $search = $ds->prepare_search();
		$search->add_field(fields => [ $ds->field('work_id') ], value => $work->value('host_work_id'));
		$search->add_field(fields => [ $ds->field('instance_number') ], value => $work->value('host_work_instance'));
		my $hosts = $search->perform_search;
		foreach my $host ($hosts->slice(0,100)) #get a maziumum of 100 - that's ludicrously high
		{
			my $host_refrains = $repo->call('refrains_in_work', $host, $depth+1);
			foreach my $r (@{$host_refrains})
			{
				$refrains->{$r->id} = $r;
			}
		}
	}

	return [values %{$refrains}];
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

	my ($record) = $list->slice(0,1); #get the first record (there should only be one)

	return $record;
};


$c->{medmus_get_reading_abstract_refrain} = sub
{
	my ($reading) = @_;

	my $ds = $reading->dataset;

	my $search = $ds->prepare_search;
	$search->add_field($ds->get_field('readings'), $reading->id);

	my $list = $search->perform_search;
	if ($list->count)
	{
		return $list->item(0); #should only be one.
	}
	print STDERR "Couldn't find Reading\n";
	return undef;
};

#override eprint render
$c->{eprint_render} = sub
{
	my( $eprint, $repository, $preview ) = @_;

	my %fragments;
	my $flags;

	my $page = $repository->xml()->create_document_fragment();
	my $title = $eprint->render_citation("brief");

	my $type = $eprint->value('medmus_type');

	if ($type eq 'refrain')
	{
		$page->appendChild($repository->call('medmus_render_refrain', $eprint));
	}
	if ($type eq 'reading')
	{
		my $refrain = $repository->call('medmus_get_reading_abstract_refrain', $eprint);
		if ($refrain)
		{
			$page->appendChild($repository->call('medmus_render_refrain', $refrain, $eprint->id));
		}	
	}
	if ($type eq 'work')
	{
		$page->appendChild($repository->call('medmus_render_work', $eprint));
	}



	my $links = $repository->xml()->create_document_fragment();

	return( $page, $title, $links );
};

