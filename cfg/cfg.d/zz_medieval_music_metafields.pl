foreach my $field(

#common to all types
{
	name => "medmus_type", type => "set", 
	options => [qw( work refrain )],
	input_style => 'medium',
},
{ name => 'instance_number', type => 'int' },

#refrain data
{ name => 'refrain_id', type => 'id' },
{ name => 'linker_number', type => 'id' },
{ name => 'abstract_text', type => 'text' },
{ name => 'circumstance', type => 'text' },
{ name => 'musical_structure', type => 'id' },

{ name => 'refrain_location', type => 'set', 'multiple' => 1, options => [qw( enté enté_interne fin_de_strophe final initial interne )]},

{
	name => 'parent_work',
	type => 'compound',
	multiple => 1,
	'fields' => [
		{ sub_name => "id", type => "text"},
		{ sub_name => "instance", type => "int"},
		{ sub_name => "location", type => "text"},
	]
},
{
	name => 'reading_texts',
	type => 'compound',
	multiple => 1,
	'fields' => [
		{ sub_name => "text", type => "text"},
		{
			sub_name => "refrain",
			type => "set",
			options => [
				'1_slf',
				'1','2','3','4','5','6','7','8','9','10',
				'triplum','duplum', 'teneur', 'enté', 'initial', 'interne', 'interne2', 'final'
			]
		},
		{ sub_name => 'stanza', type => 'int' },
		{ sub_name => 'envoi', type => 'set', options => ['I','II','III'] },
	]
},

{ name => 'singer', type => 'text', multiple => 1 },
{ name => 'audience', type => 'text', multiple => 1 },
{ name => 'function', type => 'text', multiple => 1 },
{ name => 'preceeding_lyric', type => 'text', multiple => 1 },
{ name => 'succeeding_lyric', type => 'text', multiple => 1 },
{ name => 'mark_of_discourse', type => 'text', multiple => 1 },
{ name => 'meter', type => 'text', multiple => 1 },
{ name => 'other_refrain_data', type => 'longtext', multiple => 1 },
{ name => 'other_manuscript_data', type => 'longtext', multiple => 1 },


{ name => 'manuscript_location', type => 'text' },
{ name => 'manuscript_id', type => 'text' },

#work fields
{ name => 'work_id', type => 'id' },
#{ name => 'title', type => 'text' }, existing field
{ name => 'number_of_stanzas', type => 'int' },
{ name => 'number_of_envois', type => 'int' },
{ name => 'rs_index', type => 'id' },
{ name => 't_index_motets', type => 'id' },
{ name => 't_index_songs', type => 'id' },
{ name => 'lu_index', type => 'id' },
{ name => 'vdb_index', type => 'id' },
{ name => 'number_of_parts', type => 'int' },
{ name => 'host_work_id', type => 'id' },
{ name => 'host_work_instance', type => 'int' },
{ name => 'location_in_host', type => 'text' },
{ name => 'other_data', type => 'longtext', multiple => 1 },
{ name => 'mw_index', type => 'id', multiple => 1 },
{ name => 'l_index', type => 'id', multiple => 1 },
{ name => 'edition', type => 'text', multiple => 1 },
{ name => 'date_description', type => 'text', multiple => 1 },
{ name => 'generic_descriptor', type => 'text', multiple => 1 },

{ name => 'primary_language', type => 'set', options => [qw( latin langue_d_oil )]},
{ name => 'secondary_language', type => 'set', options => [qw( latin langue_d_oil )]},
{ name => 'style_of_discourse', type => 'set', 'multiple' => 1, options => [qw( vers prose_asonancee prose )]},
{ name => 'voice_in_polyphony', type => 'set', 'multiple' => 1, options => [qw( duplum triplum quadruplum motet teneur )]},

{ name => 'authors', type => 'compound', multiple => 1, fields => [
	{ sub_name => 'name', type => 'text' },
	{ sub_name => 'location', type => 'text' },
	{ sub_name => 'assumed', type => 'boolean' },
]},

)
{
	$c->add_dataset_field( 'eprint', $field);
}
