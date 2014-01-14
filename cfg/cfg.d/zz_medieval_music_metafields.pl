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
	],
	render_value => sub {
		my ($session, $self, $value, $alllangs, $nolink, $object ) = @_;

		my @singles;
		foreach my $p (@{$value})
		{
			my $v = $p->{id} . '/' . $p->{instance};
			if ($p->{location})
			{
				$v .= ', ' . $p->{location};
			}
			push @singles, $v;
		}
		my $string =  join(' and ', @singles);
		return $session->xml->create_text_node($string);
	},
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
	],
	render_value => sub
	{
		my ($session, $field, $value, $alllangs, $nolink, $object ) = @_;

		my $xml = $session->xml;
		my $ul = $xml->create_element('ul');
		foreach my $reading (@{$value})
		{
			my $text = $reading->{text};
			$text =~ s/<([^<>]*)>/<span style="font-size: 150%">$1<\/span>/g;
			$text =~ s/{([^{}]*)}/<em>$1<\/em>/g;
			my $text_dom = EPrints::Extras::render_xhtml_field($session, $field, $text);

			#a bit of a hack to determine if it worked...
			if (EPrints::Utils::tree_to_utf8($text_dom) =~ m/Error parsing/)
			{
				$text_dom = $xml->create_text_node($text);
			}

			my $extras = '';
			if ($reading->{refrain} || $reading->{stanza} || $reading->{envoi})
			{
				my @bits;
				push @bits, 'ref. ' . $reading->{refrain} if $reading->{refrain};
				push @bits, 'st. ' . $reading->{stanza} if $reading->{stanza};
				push @bits, 'env. ' . $reading->{envoi} if $reading->{envoi};

				$extras = ' [' . join(', ', @bits) . ']';
			}
			my $li = $xml->create_element('li');
			$ul->appendChild($li);
			$li->appendChild($text_dom);
			$li->appendChild($xml->create_text_node($extras)) if $extras;
		}
		return $ul;
	}
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
{ name => 'manuscript_id', type => 'text' }, #will also be copied into works
{
	name => 'manuscript_collocation',
	type => 'text',
	virtual => 1,
	render_value => sub
	{
		my ($session, $self, $value, $alllangs, $nolink, $object ) = @_;
		my $xml = $session->xml;
		my $val = $object->value('manuscript_id');
		$val .= ', ' . $object->value('manuscript_location') if $object->is_set('manuscript_location');
		return $xml->create_text_node($val);
	}

},

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

{
	name => 'authors',
	type => 'compound',
	multiple => 1,
	fields => [
		{ sub_name => 'name', type => 'text' },
		{ sub_name => 'location', type => 'text' },
		{ sub_name => 'assumed', type => 'boolean' },
	],
	render_value => sub {
		my ($session, $self, $value, $alllangs, $nolink, $object ) = @_;

		my @singles;
		foreach my $p (@{$value})
		{
			my $v = $p->{name};
			if ($p->{location})
			{
				$v .= ' (' . $p->{location} . ')';
			}
			if ($p->{assumed} eq 'TRUE' )
			{
				$v .= '[' . $v . ']';
			}
			push @singles, $v;
		}
		my $string =  join(', ', @singles);
		return $session->xml->create_text_node($string);
	},
},

)
{
	$c->add_dataset_field( 'eprint', $field);
}