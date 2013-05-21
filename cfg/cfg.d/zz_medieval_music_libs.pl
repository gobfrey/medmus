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


#disable default functionality
$c->{set_eprint_automatic_fields} = undef;

#override eprint render
$c->{eprint_render} = sub
{
	my( $eprint, $repository, $preview ) = @_;

	my $page = $eprint->render_citation( "medmus_summary", %fragments, flags=>$flags );

	my $title = $eprint->render_citation("medmus_brief");

	my $links = $repository->xml()->create_document_fragment();

	return( $page, $title, $links );
};

