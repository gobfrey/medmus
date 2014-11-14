use Unicode::Collate;

# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_view_timeout} = 30*24*60*60; #we're a fairly static dataset, so regenerate views monthly
$c->{browse_views} = [
	{
		id => "words",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
		menus => [
			{
				fields => ["reading_texts_text_browse_index"],
				new_column_at => [0,0,0],
				mode => 'sections',
				'group_range_function' => 'EPrints::Update::Views::cluster_ranges_100',
				'open_first_section' => 1
			},
			{
				fields => ["abstract_text"]
			}
		],
		citation => 'simple_view',
                order => "browse_list_order",#refrain id for refrains, title for works
		max_items => 10000,
	},
	{
		id => "abstract_item",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
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
                id => "refrain_manuscript",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
                menus => [
			{
				fields => ["manuscript_id"],
				new_column_at => [0,0],
				render_menu => 'render_manuscript_menu',
			}
		],
                order => "browse_list_order",#refrain id for refrains, title for works
		max_items => 10000,
		filters => [{ meta_fields=>[qw( medmus_type )], value=>"refrain" }], 
        },
        {
                id => "work_manuscript",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
                menus => [
			{
				fields => ["manuscript_id"],
				new_column_at => [0,0],
				render_menu => 'render_manuscript_menu',
			}
		],
                order => "browse_list_order",#refrain id for refrains, title for works
		variations => ['work_type'],
		filters => [{ meta_fields=>[qw( medmus_type )], value=>"work" }], 
		max_items => 10000,
        },

	{
		id => "author",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
		menus => [
			{
				fields => ["authors_name"],
				new_column_at => [0,0],
			},
			{
				fields => ['work_type'],
			},
			{
				fields => ["abstract_work_title"]
			}
		],
                order => "browse_list_order",#refrain id for refrains, title for works
	},



	{
		id => "generic_descriptor",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
		menus => [
			{
				fields => ["generic_descriptor_browse"],
			},
			{
				fields => ["abstract_work_title"]
			}
		],
		order => "browse_list_order",
	},
	{
		id => "singer",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
		menus => [
			{
				fields => ["singer_browse"],
				new_column_at => [0,0,],

			},
			{
				fields => ["abstract_text"]
			}
		],
		order => "eprintid",
		max_items => 10000,
                order => "browse_list_order",#refrain id for refrains, title for works
	},
	{
		id => "circumstance",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
		menus => [
			{
				fields => ["circumstance_browse"],
			},
			{
				fields => ["abstract_text"]
			}
		],
		order => "eprintid",
		max_items => 10000,
                order => "browse_list_order",#refrain id for refrains, title for works
	},
	{
		id => "voice_in_polyphony",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
		menus => [
			{
				fields => ["voice_in_polyphony"],
			},
			{
				fields => ["abstract_work_title"]
			}
		],
		max_items => 10000,
                order => "browse_list_order",#refrain id for refrains, title for works
	},
	{
		id => "refrain_location",
		max_menu_age => $c->{browse_view_timeout},
		max_list_age => $c->{browse_view_timeout},
		menus => [
			{
				fields => ["refrain_location"],
			},
			{
				fields => ["abstract_text"]
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

	#the collator needs to ignore formatting characters, *and* it appears to be ignoring spaces, so replace them with zeros
	my $collator = Unicode::Collate->new( preprocess => sub { my $str = shift; $str =~ s/\s/0/g; $str =~ s/[<>{}\[\]()\.,:\/]//g; return $str;} );
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
				my $title = $eprint->value('abstract_work_title');
				#filter out clusula and organums
				if ($title !~ m/parts (clausula|organum)/)
				{
					my $number_of_parts = $eprint->value('number_of_parts');
					if (
						$number_of_parts &&
						(
							$number_of_parts == 2 ||
							$number_of_parts == 3 ||
							$number_of_parts == 4
						)
					)
					{
						$sections->{$number_of_parts . '_part_motets'}->{$work_id}->{orderval} =  $title;
						$sections->{$number_of_parts . '_part_motets'}->{$work_id}->{rendered} = $eprint->render_value('abstract_work_title');
					}
				}
			}
			elsif ( ($work_id =~ m/^M/) )
			{
				my $m_index;
				if ($eprint->is_set('m_index'))
				{
					$sections->{'motet_parts'}->{$work_id}->{orderval} = $repo->call('pad_numeric_parts',$work_id);
					$m_index = $eprint->render_value('lu_index'); #m index and lu_index are the same?  Not sure why I'm checking for one being set and using the other.  Seems to work though...
				}
				else
				{
					$sections->{'motet_parts'}->{$work_id}->{orderval} = '000' . $eprint->value('abstract_work_title'); #sort after the ones with IDs
					$m_index = $xml->create_text_node('Unindexed');
				}
				my $frag = $xml->create_document_fragment;
				$frag->appendChild($m_index);
				$frag->appendChild($xml->create_text_node(': '));
				$frag->appendChild($eprint->render_value('abstract_work_title'));
				$sections->{'motet_parts'}->{$work_id}->{rendered} = $frag;
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
					$sections->{'song_no_rs'}->{$work_id}->{orderval} = $eprint->value('abstract_work_title');
					$sections->{'song_no_rs'}->{$work_id}->{rendered} = $eprint->render_value('abstract_work_title');

				}
				$frag->appendChild($eprint->render_value('abstract_work_title'));
			}
			elsif ( $work_id =~ m/^N/ )
			{
				$sections->{'narrative'}->{$work_id}->{rendered} = $eprint->render_value('abstract_work_title');
				$sections->{'narrative'}->{$work_id}->{orderval} = $eprint->value('abstract_work_title');
			}
		}
	}, $sections);

	my $tab_headings = [];
	my $tab_contents = [];
	
	foreach my $tabtitle (qw/ refrain song song_no_rs 2_part_motets 3_part_motets 4_part_motets motet_parts narrative /)
	{
		push @{$tab_headings}, $repo->html_phrase("view_abstract_item_tabtitle_$tabtitle"); 

		my $tabcontent = $xml->create_document_fragment;
		push @{$tab_contents}, $tabcontent;

		my $ul = $xml->create_element('ul');
		$tabcontent->appendChild($ul);

		#the collator needs to ignore formatting characters, *and* it appears to be ignoring spaces, so replace them with zeros
		my $collator = Unicode::Collate->new( preprocess => sub { my $str = shift; $str =~ s/\s/0/g; $str =~ s/[<>{}\[\]()\.,:\/]//g; return $str;} );

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

	my $h1 = $xml->create_element('h1');
	$h1->appendChild($item_list->[0]->render_citation('brief'));
	$frag->appendChild($h1);

	my @instances = sort {$a->value('instance_number') <=> $b->value('instance_number')} @{$item_list};

	foreach my $refrain (@instances)
	{
		my $refrain_frags = {};
		my $refrain_box_id = $refrain->value('refrain_id') . '-' . $refrain->value('instance_number');
		my $refrain_box_title = $xml->create_text_node($refrain->value('instance_number') . ': In ' . $refrain->value('manuscript_collocation'));

		my $parent = $repo->call('refrain_parent', $refrain);
		my $parent_box_title = $xml->create_text_node('Parent Work: ' . $parent->value('abstract_work_title'));
		my $parent_frags = {};
		my $parent_box_id = $refrain_box_id . '--' . $parent->value('work_id') . '-' . $parent->value('instance_number');

		my $host = $repo->call('work_host', $parent);
		if ($host)
		{
			my $host_box_id = $parent_box_id . '--' . $host->value('work_id') . '-' . $parent->value('instance_number');
			my $host_box_title = $xml->create_text_node('Hosted in: ' . $host->value('abstract_work_title'));
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

	my $h1 = $xml->create_element('h1');
	$h1->appendChild($item_list->[0]->render_citation('brief'));
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
			my $hosted_work_box_title = $xml->create_text_node('Hosted Work: ' . $hosted_work->value('abstract_work_title'));
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


