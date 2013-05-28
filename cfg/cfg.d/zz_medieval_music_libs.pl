push @{$c->{fields}->{eprint}},

	{
		name => "medmus_type", type => "set", 
        	options => [qw(
			work
			reading
			refrain
        	)],
        	input_style => 'medium',
	},

#work fields
#work to do
	#title -- exists in default cfg.

#reading fields
	{ name => "audience", type => "text" },
	{ name => "circumstance", type => "text" },
	{ name => "discourse", type => "text" },
	{ name => "function", type => "text" },
	{ name => "location", type => "text" },
	{ name => "manuscript_collocation", type => "id" },
	{ name => "meter", type => "text" },
	{ name => "other_data", type => "text" },
	{ name => "preceding_cue", type => "text" },
	{ name => "singer", type => "text" },
	{ name => "succeeding_cue", type => "text" },

	{ name => "source_data_row", type => "text" },
	{ name => "source_data_reading_blob", type => "text" },
	{ name => "stave_image_rel_path", type => "text" },

	{ name => "parent_l_index", type => "text" },
	{ name => "parent_lu_index", type => "text" },
	{ name => "parent_mw_index", type => "text" },
	{ name => "parent_rs_index", type => "text" },
	{ name => "parent_rs_index_stanza", type => "text" },
	{ name => "parent_t_index_songs", type => "text" },
	{ name => "parent_t_indices", type => "text", multiple => 1 },
	{ name => "parent_vdb_index", type => "text" },

	#note that master_text is used as an internal field to use one of the reading_text fields for the purposes of citations
	{ name => "reading_text", type => "text" },
	{
		name => "reading_texts",
		 type => "compound",
		 multiple => 1,
		 fields =>
		[
			{ sub_name => "text", type => "text"},
			{ sub_name => "position", type => "text" }
		]
	},


#refrain fields
	{ name=>"master_text", type => "text", required => 1},
	{ name=>"reference_number", type => "id", required => 1},
	{ name=>"readings", type=>'itemref', datasetid => 'eprint', 'multiple' => 1 },


;


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

	my $reading_ids = $refrain->value('readings');

	foreach my $id (@{$reading_ids})
	{
		my $reading = $repo->eprint($id);

		my %box_args = (
			'title' => $reading->render_citation('brief'),
			'content' => $reading->render_citation('reading_box_content'),
			'id' => 'medmus_reading_box_' . $id,
			'session' => $repo,
			'collapsed' => 1,
		);

		$frag->appendChild(EPrints::Box::render(%box_args));
	}


	return $frag;
};

#disable default functionality
$c->{set_eprint_automatic_fields} = sub
{
	my ($eprint) = @_;

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


};

$c->{medmus_get_reading_abstract_refrain} = sub
{
	my ($reading) = @_;

	my $ds = $reading->dataset;

	my $search = $ds->prepare_search;
	$search->add_field($ds->get_field('readings'), $reading->id);

	my $list = $search->execute;
	if ($list->count)
	{
		return $list->item(0); #should only be one.
	}
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


	my $links = $repository->xml()->create_document_fragment();

	return( $page, $title, $links );
};

