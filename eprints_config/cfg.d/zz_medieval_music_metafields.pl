foreach my $field(

#common to all types
{
	name => "medmus_type", type => "set", 
	options => [qw( work refrain )],
	input_style => 'medium',
},
{ name => 'instance_number', type => 'int' },
{ name => 'manuscript_location', type => 'text' },
{ name => 'manuscript_id', type => 'text' }, #will also be copied into works
{ name => 'other_manuscript_data', type => 'longtext', multiple => 1 },
{ name => 'manuscript_collocation', type => 'text', volatile => 1 }, #for rendering
{ name => 'abstract_item_browse', type => 'text', volatile => 1 }, #for browse view
{ name => 'browse_list_order', type => 'id'}, #for ordering in browse views


#refrain data
{ name => 'refrain_id', type => 'id', make_value_orderkey => 'medmus_id_orderval', browse_link => 'abstract_item' },
{ name => 'refrain_id_browse', type => 'text', volatile => 1, make_value_orderkey => 'medmus_id_orderval'}, #for rendering the links in the browse view


{ name => 'linker_number', type => 'id' },
{ name => 'abstract_text', type => 'text' },
{ name => 'circumstance', type => 'text' },
{ name => 'circumstance_browse', type => 'text', multiple => 1, volatile => 1 },
{ name => 'musical_structure', type => 'id' },
{ name => 'image_file', type => 'text' },

{ name => 'refrain_location', type => 'set', 'multiple' => 1, options => [qw( enté enté_interne fin_de_strophe final initial interne )]},

{ name => 'parent_work_id', type => 'id' },
{ name => 'parent_work_instance', type => 'int' },
{ name => 'location_in_parent', type => 'text' },
{
	name => 'parent_work',
	type => 'text',
	volatile => 1,
	render_value => sub
	{
		my ($session, $field, $value, $alllangs, $nolink, $object ) = @_;

		#naming consistency fix...
		my $refrain = $object;
		my $repo = $session;

		my $xml = $repo->xml;
		my $frag = $xml->create_document_fragment;

		return $frag unless $refrain->is_set('parent_work_id');

	        my $parent = $repo->call('refrain_parent', $refrain);
		if ($parent)
		{
			$frag->appendChild($parent->render_citation_link('brief'));
			if ($refrain->is_set('location_in_parent'))
			{
				$frag->appendChild($xml->create_text_node(' ['));
				$frag->appendChild($refrain->render_value('location_in_parent'));
				$frag->appendChild($xml->create_text_node(' ]'));
			}
		}
		else
		{
			my $text = $refrain->value('parent_work_id') . '/' . $refrain->value('parent_work_instance');
			$text .= ' [' . $refrain->value('location_in_parent') . ']' if $refrain->is_set('location_in_parent');
			$text .= ' (ERR)';
			$frag->appendChild($xml->create_text_node($text));
		}	
		return $frag;
	}
},#for rendering

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
{ name => 'reading_texts_text_browse_index', type => 'text', multiple => 1, volatile => 1, make_value_orderkey => 'medmus_utf8_string_orderval'  },

{ name => 'singer', type => 'text', multiple => 1 },
{ name => 'singer_browse', type => 'text', multiple => 1, volatile => 1 }, #for browsing
{ name => 'audience', type => 'text', multiple => 1 },
{ name => 'function', type => 'text', multiple => 1 },
{ name => 'preceeding_lyric', type => 'text', multiple => 1 },
{ name => 'succeeding_lyric', type => 'text', multiple => 1 },
{ name => 'mark_of_discourse', type => 'text', multiple => 1 },
{ name => 'meter', type => 'text', multiple => 1 },
{ name => 'other_refrain_data', type => 'longtext', multiple => 1 },


#work fields
{ name => 'work_id', type => 'id', make_value_orderkey => 'medmus_id_orderval' },
{ name => 'work_id_browse', type => 'text', volatile => 1, make_value_orderkey => 'medmus_id_orderval'}, #for rendering the links in the browse view
{ name => 'work_type', type => 'text', volatile => 1 }, #the type of work, used in some browse views

#{ name => 'title', type => 'text' }, existing field
{ name => 'title_input', type => 'text' },
{ name => 'abstract_work_title', type => 'text' },
{ name => 'number_of_stanzas', type => 'id' }, #usually a number, but sometimes text
{ name => 'number_of_envois', type => 'id' }, #usually a number, but sometimes text
{ name => 'rs_index', type => 'id' },
{ name => 't_index_motets', type => 'id' },
{ name => 't_index_songs', type => 'id' },
{ name => 'lu_index', type => 'id' },
{ name => 'm_index', type => 'id' },
{ name => 'vdb_index', type => 'id' },
{ name => 'number_of_parts', type => 'id' }, #usually a number, but sometimes text
{ name => 'host_work_id', type => 'id' },
{ name => 'host_work_instance', type => 'id' }, #usually a number, but sometimes text
{ name => 'location_in_host', type => 'text' },
{
	name => 'host_work',
	type => 'text',
	volatile => 1,
	render_value => sub
	{
		my ($session, $field, $value, $alllangs, $nolink, $object ) = @_;

		#naming consistency fix...
		my $work = $object;
		my $repo = $session;

		my $xml = $repo->xml;
		my $frag = $xml->create_document_fragment;

		return $frag unless $work->is_set('host_work_id');

	        my $host = $repo->call('work_host', $work);
		if ($host)
		{
			$frag->appendChild($host->render_citation_link('brief'));
			if ($work->is_set('location_in_host'))
			{
				$frag->appendChild($xml->create_text_node(' ['));
				$frag->appendChild($work->render_value('location_in_host'));
				$frag->appendChild($xml->create_text_node(']'));
			}
		}
		else
		{
			my $text = $work->value('host_work_id') . '/' . $work->value('host_work_instance');
			$text .= ' (ERR)';
			$frag->appendChild($xml->create_text_node($text));
		}	
		return $frag;
	}
},# for rendering
{ name => 'other_data', type => 'longtext', multiple => 1 },
{ name => 'mw_index', type => 'id', multiple => 1 },
{ name => 'l_index', type => 'id', multiple => 1 },
{ name => 'edition', type => 'text', multiple => 1 },
{ name => 'date_description', type => 'text', multiple => 1 },
{ name => 'generic_descriptor', type => 'text', multiple => 1 },
{ name => 'generic_descriptor_browse', type => 'text', multiple => 1 },
{ name => 'author_commentary', type => 'text', multiple => 1 },

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
				$v = '[' . $v . ']';
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


$c->{medmus_utf8_string_orderval} = sub
{
	my ($field, $value, $session, $langid, $dataset) = @_;

	my $orderval = lc($value);

	return $orderval;
};

#pad all numeric parts of the ID with zeros
$c->{medmus_id_orderval} = sub
{
	my ($field, $value, $session, $langid, $dataset) = @_;

	return $session->call('pad_numeric_parts', $value);
}
