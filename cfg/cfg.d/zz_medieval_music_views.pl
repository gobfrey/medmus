use Unicode::Collate;

# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_views} = [
	{
		id => "words",
		menus => [
			{
				fields => ["reading_texts_text_browse_index"],
				new_column_at => [0,0,0],
				mode => 'sections',
				'group_range_function' => 'EPrints::Update::Views::cluster_ranges_100',
				'open_first_section' => 1
			}
		],
		citation => 'simple_view',
                order => "browse_list_order",#refrain id for refrains, title for works
		max_items => 10000,
	},
	{
		id => "abstract_item",
		menus => [{
			fields => ["work_id","refrain_id"],
			new_column_at => [0],
			allow_null => 0,
			render_menu => 'render_abstract_item_menu',
		}],
		variations => [
			"DEFAULT;render_fn=render_abstract_item_browse_list"
		],
		hideup => 1,
	},
        {
                id => "manuscript",
                menus => [
			{
				fields => ["medmus_type"],
			},
			{
				fields => ["manuscript_id"],
				new_column_at => [0,0],
				render_menu => 'render_manuscript_menu',
			}
		],
                order => "browse_list_order",#refrain id for refrains, title for works
		max_items => 10000,
        },

	{
		id => "author",
		menus => [
			{
				fields => ["authors_name"],
				new_column_at => [0,0],
			}
		],
                order => "browse_list_order",#refrain id for refrains, title for works
	},



	{
		id => "generic_descriptor",
		menus => [
			{
				fields => ["generic_descriptor_browse"],
			}
		],
		order => "browse_list_order",
	},
	{
		id => "singer",
		menus => [
			{
				fields => ["singer_browse"],
				new_column_at => [0,0,],

			}
		],
		order => "eprintid",
		max_items => 10000,
                order => "browse_list_order",#refrain id for refrains, title for works
	},
	{
		id => "circumstance",
		menus => [
			{
				fields => ["circumstance_browse"],
			}
		],
		order => "eprintid",
		max_items => 10000,
                order => "browse_list_order",#refrain id for refrains, title for works
	},
	{
		id => "voice_in_polyphony",
		menus => [
			{
				fields => ["voice_in_polyphony"],
			}
		],
		max_items => 10000,
                order => "browse_list_order",#refrain id for refrains, title for works
	},
	{
		id => "refrain_location",
		menus => [
			{
				fields => ["refrain_location"],
			}
		],
                order => "browse_list_order",#refrain id for refrains, title for works
		max_items => 10000,
	},






#	{
#		id => "work_style_of_discourse",
#		menus => [
#			{
#				fields => ["style_of_discourse"],
#			}
#		],
#		order => "eprintid",
#		max_items => 10000,
#	},
#	{
#		id => "work_language",
#		menus => [
#			{
#				fields => ["primary_language", "secondary_language"],
#				hide_empty => 1,
#			}
#		],
#		order => "eprintid",
#		max_items => 10000,
#	},
#	{
#		id => "function",
#		menus => [
#			{
#				fields => ["function"],
#				new_column_at => [0,0,],
#
#			}
#		],
#		order => "eprintid",
#		max_items => 10000,
#	},
];

$c->{refrain_view_refrain_details_fields} = [qw/
refrain_location

singer
audience
function
circumstance

preceeding_lyric
succeeding_lyric
mark_of_discourse

musical_structure
meter

other_refrain_data

/];
$c->{refrain_view_work_fields} = [qw/
title
authors
author_commentary
edition
generic_descriptor
date_description
l_index
mw_index
rs_index
t_index_motets
t_index_songs
lu_index
vdb_index
number_of_parts
voice_in_polyphony
primary_language
secondary_language
style_of_discourse
number_of_stanzas
number_of_envois
other_data
/];

#needed to order the numeric subparts of manuscripts
$c->{render_manuscript_menu} = sub
{
	my ( $repo, $menu, $sizes, $values, $fields, $has_submenu, $view ) = @_;

	my $collator = Unicode::Collate->new( preprocess => sub { my $str = shift; $str =~ s/[<>{}\[\]()\.,:\/]//g; return $str;} );
	my @sorted_values = sort { $collator->cmp(
		$repo->call('pad_numeric_parts',$a),
		$repo->call('pad_numeric_parts',$b)
	) } @{$values};

	return EPrints::Update::Views::render_menu( $repo, $menu, $sizes, \@sorted_values, $fields, $has_submenu, $view );
};

$c->{render_abstract_item_menu} = sub
{
	my( $repo, $view, $sizes, $values, $fields, $has_submenu ) = @_;

	my $xml = $repo->xml();
	my $xhtml = $repo->xhtml();

	my $items = $repo->dataset('archive');

	my $sections = {};

	$items->search()->map( sub {
		my ($repo, $dataset, $eprint, $sections) = @_;

		my $type = $eprint->value('medmus_type');

		if ($type eq 'refrain')
		{
			$sections->{refrain}->{$eprint->value('refrain_id')}->{rendered} =
				$eprint->render_citation('brief');
			$sections->{refrain}->{$eprint->value('refrain_id')}->{orderval} =
				$repo->call('pad_numeric_parts',$eprint->value('refrain_id'));
		}
		else
		{
			my $work_id = $eprint->value('work_id');

			if ( ($work_id =~ m/^Li/) || ($work_id =~ m/^Machaut/) )
			{
				my $title = $eprint->value('title');
				#filter out clusula and organums
				if ($title !~ m/parts (clausula|organum)/)
				{
					$sections->{'motet'}->{$work_id}->{orderval} = $eprint->value('title');
					$sections->{'motet'}->{$work_id}->{rendered} = $eprint->render_citation('brief');
				}
			}
			elsif ( ($work_id =~ m/^M/) )
			{
				if ($eprint->is_set('m_index'))
				{
					$sections->{'motet_parts'}->{$work_id}->{orderval} = $repo->call('pad_numeric_parts',$work_id);
					my $frag = $xml->create_document_fragment;
					$frag->appendChild($eprint->render_value('lu_index'));
					$frag->appendChild($xml->create_text_node(': '));
					$frag->appendChild($eprint->render_value('title'));
					$sections->{'motet_parts'}->{$work_id}->{rendered} = $frag;
				}
				else
				{
					$sections->{'motet_parts'}->{$work_id}->{orderval} = 'Z' . $eprint->value('title'); #sort after the ones with IDs
					$sections->{'motet_parts'}->{$work_id}->{rendered} = $eprint->render_citation('brief');
				}
			}
			elsif ( ($work_id =~ m/^C/) || ($work_id =~ m/^R/) || ($work_id =~ m/^L/) )
			{
				my $frag = $xml->create_document_fragment;
				if ($eprint->is_set('rs_index'))
				{
					$sections->{'song'}->{$work_id}->{rendered} = $frag;
					$sections->{'song'}->{$work_id}->{orderval} = 
						$repo->call('pad_numeric_parts',$eprint->value('rs_index'));
					$frag->appendChild($xml->create_text_node('RS'));
					$frag->appendChild($eprint->render_value('rs_index'));
					$frag->appendChild($xml->create_text_node(': '));
				}
				else
				{
					$sections->{'song_no_rs'}->{$work_id}->{orderval} = $eprint->value('title');
					$sections->{'song_no_rs'}->{$work_id}->{rendered} = $eprint->render_value('title');

				}
				$frag->appendChild($eprint->render_value('title'));
			}
			elsif ( $work_id =~ m/^N/ )
			{
				$sections->{'narrative'}->{$work_id}->{rendered} = $eprint->render_value('title');
				$sections->{'narrative'}->{$work_id}->{orderval} = $eprint->value('title');
			}
		}
	}, $sections);

	my $tab_headings = [];
	my $tab_contents = [];
	
	foreach my $tabtitle (qw/ refrain song song_no_rs motet motet_parts narrative /)
	{
		push @{$tab_headings}, $repo->html_phrase("view_abstract_item_tabtitle_$tabtitle"); 

		my $tabcontent = $xml->create_document_fragment;
		push @{$tab_contents}, $tabcontent;

		my $ul = $xml->create_element('ul');
		$tabcontent->appendChild($ul);

		my $collator = Unicode::Collate->new( preprocess => sub { my $str = shift; $str =~ s/[<>{}\[\]()\.,:\/]//g; return $str;} );
		foreach my $value (sort { $collator->cmp(
			$sections->{$tabtitle}->{$a}->{orderval},
			$sections->{$tabtitle}->{$b}->{orderval}
		) } keys %{$sections->{$tabtitle}})
		{
			my $li = $xml->create_element('li');
			$ul->appendChild($li);
			
			# work out what filename to link to 
			my $fileid = $fields->[0]->get_id_from_value( $repo, $value );
			my $link = EPrints::Utils::escape_filename( $fileid );
			if( $has_submenu ) { $link .= '/'; } else { $link .= '.html'; }

			my $a = $repo->render_link( $link );
			$li->appendChild($a);
			$a->appendChild($sections->{$tabtitle}->{$value}->{rendered});

			my $size = 0;
			$size = $sizes->{$value} if( defined $sizes && defined $sizes->{$value} );
			$li->appendChild($xml->create_text_node(" ($size)"));

		}
	}

	return $xhtml->tabs( $tab_headings, $tab_contents);



	my $table = $xml->create_element( "table" );
	my $columns = 3;
	my $tr = $xml->create_element( "tr" );
	$table->appendChild( $tr );
	my $cells = 0;
	foreach my $value ( @{$values} )
	{
		my $size = 0;
		$size = $sizes->{$value} if( defined $sizes && defined $sizes->{$value} );

		next if( $view->{hideempty} && $size == 0 );

		if( $cells > 0 && $cells % $columns == 0 )
		{
			$tr = $xml->create_element( "tr" );
			$table->appendChild( $tr );
		}

		# work out what filename to link to 
		my $fileid = $fields->[0]->get_id_from_value( $repo, $value );
		my $link = EPrints::Utils::escape_filename( $fileid );
		if( $has_submenu ) { $link .= '/'; } else { $link .= '.html'; }

		my $td = $xml->create_element( "td", style=>"padding: 1em; text-align: center;vertical-align:top" );
		$tr->appendChild( $td );

		my $a1 = $repo->render_link( $link );
		my $piccy = $xml->create_element( "span", style=>"display: block; width: 200px; height: 150px; border: solid 1px #888; background-color: #ccf; padding: 0.25em" );
		$piccy->appendChild( $xml->create_text_node( "Imagine I'm a picture!" ));
		$a1->appendChild( $piccy );
		$td->appendChild( $a1 );

		my $a2 = $repo->render_link( $link );
		$a2->appendChild( $fields->[0]->get_value_label( $repo, $value ) );
		$td->appendChild( $a2 );

		$cells += 1;
	}

	return $table;
};

$c->{pad_numeric_parts} = sub
{
	my ($value) = @_;

	my @chars = split(//, $value);

	my $orderval;
	my $int_part;

	while (scalar @chars)
	{
		my $next_char = shift @chars;
		if ($next_char =~ m/[0-9]/)
		{
			$int_part .= $next_char;
		}
		else
		{
			if ($int_part)
			{
				$orderval .= sprintf("%08s", $int_part);
				$int_part = '';
			}
			$orderval .= $next_char;
		}
	}
	if ($int_part)
	{
		$orderval .= sprintf("%08s", $int_part);
	}
	return $orderval;

};


$c->{render_abstract_item_browse_list} = sub
{
	my( $repo, $item_list, $view_definition, $path_to_this_page, $filename ) = @_;

	#expecting all items in the list to have the same medmus_type
	my $list_type = $item_list->[0]->value('medmus_type');

	if ($list_type eq 'work')
	{
		return $repo->call('render_work_browse', $repo, $item_list, $view_definition, $path_to_this_page, $filename);
	}
	if ($list_type eq 'refrain')
	{
		return $repo->call('render_refrain_browse', $repo, $item_list, $view_definition, $path_to_this_page, $filename);
	}

	#we should never get here
	return $repo->create_document_fragment;
};


#browse view render for refrains
$c->{render_refrain_browse} = sub
{
	my( $repo, $item_list, $view_definition, $path_to_this_page, $filename ) = @_;

	my $xml = $repo->xml();

	my $frag = $xml->create_document_fragment;

	#Abstract Refrain information
	my $abstract_text = $item_list->[0]->render_value('abstract_text');
	my $id = $item_list->[0]->render_value('refrain_id');

	my $h1 = $xml->create_element('h1');
	$h1->appendChild($xml->create_text_node('vdB '));
	$h1->appendChild($id);
	$h1->appendChild($xml->create_text_node(': '));
	$h1->appendChild($abstract_text);
	$frag->appendChild($h1);

	my @instances = sort {$a->value('instance_number') <=> $b->value('instance_number')} @{$item_list};

	foreach my $refrain (@instances)
	{
		my $refrain_frags = {};
		my $refrain_box_id = $refrain->value('refrain_id') . '-' . $refrain->value('instance_number');
		my $refrain_box_title = $xml->create_text_node($refrain->value('instance_number') . ': In ' . $refrain->value('manuscript_collocation'));

		my $parent = $repo->call('refrain_parent', $refrain);
		my $parent_box_title = $xml->create_text_node('Parent Work: ' . $parent->value('title'));
		my $parent_frags = {};
		my $parent_box_id = $refrain_box_id . '--' . $parent->value('work_id') . '-' . $parent->value('instance_number');

		my $host = $repo->call('work_host', $parent);
		if ($host)
		{
			my $host_box_id = $parent_box_id . '--' . $host->value('work_id') . '-' . $parent->value('instance_number');
			my $host_box_title = $xml->create_text_node('Hosted in: ' . $host->value('title'));
			$parent_frags->{host_box} = $repo->call('render_work_for_browse_box', $host, $host_box_title, $host_box_id, {}, 1);
		}

		$refrain_frags->{'parent_box'} = $repo->call('render_work_for_browse_box', $parent, $parent_box_title, $parent_box_id, $parent_frags, 1);

		$frag->appendChild($repo->call('render_refrain_for_browse_box', $refrain, $refrain_box_title, $refrain_box_id, $refrain_frags, 0));
	}

	return $frag;
};

$c->{render_work_browse} = sub
{
	my( $repo, $item_list, $view_definition, $path_to_this_page, $filename ) = @_;

	my $xml = $repo->xml();

	my $frag = $xml->create_document_fragment;

	#Abstract Refrain information
	my $title = $item_list->[0]->render_value('title');
	my $id = $item_list->[0]->render_value('work_id');

	my $h1 = $xml->create_element('h1');
	$h1->appendChild($id);
	$h1->appendChild($xml->create_text_node(': '));
	$h1->appendChild($title);
	$frag->appendChild($h1);

	my @instances = sort {$a->value('instance_number') <=> $b->value('instance_number')} @{$item_list};

	foreach my $work (@instances)
	{
		my $work_frags = {};
		my $work_box_title = $xml->create_text_node($work->value('instance_number') . ': In ' . $work->value('manuscript_collocation'));
		my $work_box_id = $work->value('work_id') . '-' . $work->value('instance_number');

		my $hosted_works = $repo->call('hosted_works', $work);
		my $hosted_works_frag = $xml->create_document_fragment;
		foreach my $hosted_work (@{$hosted_works})
		{
			my $hosted_work_frags = {};
			my $hosted_work_box_title = $xml->create_text_node('Hosted Work: ' . $hosted_work->value('title'));
			my $hosted_work_box_id = $work_box_id . '--' . $hosted_work->value('work_id') . '-' . $hosted_work->value('instance_number');

			$hosted_work_frags->{child_refrains_boxes} = $repo->call('render_work_browse_render_child_refrains', $hosted_work, $hosted_work_box_id);

			$hosted_works_frag->appendChild($repo->call('render_work_for_browse_box', $hosted_work, $hosted_work_box_title, $hosted_work_box_id, $hosted_work_frags, 1));
		}

		$work_frags->{hosted_works_boxes} = $hosted_works_frag;
		$work_frags->{child_refrains_boxes} = $repo->call('render_work_browse_render_child_refrains', $work, $work_box_id);

		$frag->appendChild($repo->call('render_work_for_browse_box', $work, $work_box_title, $work_box_id, $work_frags, 0));
	}

	return $frag;
};

$c->{render_work_browse_render_child_refrains} = sub
{
	my ($work, $work_box_id) = @_;
	my $repo = $work->repository;
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	#get all refrains
	my $refrains = $repo->call('refrains_in_work', $work, 5); #note '5' will prevent refrains in hosted works being retured

	foreach my $refrain(@{$refrains})
	{
		my $refrain_box_id = $work_box_id . '--' . $refrain->value('refrain_id') . '-' . $refrain->value('instance_number');
		my $refrain_box_title = $xml->create_text_node('Refrain vdB ' . $refrain->value('refrain_id') . ': ' . $refrain->value('abstract_text'));

		$frag->appendChild($repo->call('render_refrain_for_browse_box', $refrain, $refrain_box_title, $refrain_box_id, {}, 1));
	}

	return $frag;
};

$c->{render_work_for_browse_box} = sub
{
	my ($work, $box_title, $box_id, $frags, $collapsed) = @_; 
	my $repo = $work->repository;
	$collapsed = 1 unless defined $collapsed;

	my $flags = {};
	my %fragments = ();

	foreach my $f (keys %{$frags})
	{
		$flags->{$f} = 1;
		$fragments{$f} = $frags->{$f};
	}

	#insert types into fragments (they're all DOM)
	foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }

	my $content = $work->render_citation('browse_view_work_box_content', %fragments, flags => $flags);

	my %options = (
		id => $box_id,
		content => $content,
		title => $box_title,
		session => $repo,
		collapsed => $collapsed
	);

	return EPrints::Box::render(%options);

};


$c->{render_refrain_for_browse_box} = sub
{
	my ($refrain, $box_title, $box_id, $frags, $collapsed) = @_;
	my $repo = $refrain->repository;
	my $xml = $repo->xml;
	$collapsed = 1 unless defined $collapsed;

	my $flags = {};
	my %fragments = ();

	foreach my $f (keys %{$frags})
	{
		$flags->{$f} = 1;
		$fragments{$f} = $frags->{$f};
	}

	$flags->{music_img} = 0;
	my @docs = $refrain->get_all_documents;

	foreach my $doc (@docs)
	{
		if ($doc->value('format') eq 'image')
		{
			$flags->{music_img} = 1;
			$fragments{music_img} = $xml->create_element('img', src => $doc->url, class => "music");
			last; #only one image per item
		}	
	}

	#insert types into fragments (they're all DOM)
	foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }

	my $content = $refrain->render_citation('browse_view_refrain_box_content', %fragments, flags => $flags);

	my %options = (
		id => $box_id,
		content => $content,
		title => $box_title,
		session => $repo,
		collapsed => $collapsed 
	);

	return EPrints::Box::render(%options);
};


