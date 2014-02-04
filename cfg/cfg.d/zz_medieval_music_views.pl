
# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_views} = [
	{
		id => "refrain",
		menus => [{
			fields => ['refrain_id'],
			new_column_at => [0,0],
			allow_null => 0,
		}],
		variations => [
			"DEFAULT;render_fn=render_refrain_browse"
		],
		hideup => 1,
	},
        {
                id => "type",
                menus => [
			{
				fields => ["medmus_type"],
				new_column_at => [0,0],
			}
		],
                order => "eprintid",
		max_items => 10000,
        },
        {
                id => "manuscript",
                menus => [
			{
				fields => ["manuscript_id"],
				new_column_at => [0,0],
			}
		],
                order => "eprintid",
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
		order => "eprintid",
	},
	{
		id => "work_id",
		menus => [
			{
				fields => ["work_id"],
				new_column_at => [0,0,0,0],
			}
		],
		order => "eprintid",
	},
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

	foreach my $instance (@instances)
	{
		my $parent = $repo->call('refrain_parent', $instance);

		#the function call will generate a box of parent information or an error box
		my $parent_box = $repo->call('render_refrain_browse_render_parent_box', $instance, $parent );

		my $flags = { parent => 1};
		my %fragments = ( parent_box => $parent_box);

		$flags->{music_img} = 0;
		my @docs = $instance->get_all_documents;

		foreach my $doc (@docs)
		{
			if ($doc->value('format') eq 'image')
			{
				$flags->{music_img} = 1;
				$fragments{music} = $xml->create_element('img', src => $doc->url, class => "music");
				last; #only one image per item
			}	
		}

		#insert types into fragments (they're all DOM)
		foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }
		my $content = $instance->render_citation('refrain_view_refrain_boxcontent', %fragments, flags => $flags);

		my @id_parts = (
			$instance->value('refrain_id'),
			$instance->value('instance_number'),
		);

		my %options = (
			id => 'refrainbox_' .  join('-',@id_parts),
			content => $content,
			title => $instance->render_citation('refrain_view_refrain_boxtitle'),
			session => $repo,
			collapsed => 0 
		);

		$frag->appendChild(EPrints::Box::render(%options));
	}

	return $frag;
};

$c->{render_refrain_browse_render_parent_box} = sub
{
	my ($refrain, $parent) = @_;
	my $repo = $refrain->repository;

	#construct an ID for javascript to use
	my $box_id_parts = [];
	foreach my $fieldname (qw/ refrain_id instance_number parent_work_id parent_work_instance /)
	{
		push @{$box_id_parts}, $refrain->value($fieldname) if $refrain->is_set($fieldname);
	}
	my $box_id = 'parentbox_' . join('-',@{$box_id_parts});

	my %options = (
		id => $box_id,
		session => $repo,
		collapsed => 1
	);

	if (!$parent)
	{
		#return a box with an error message
		my $parent_work_dom = $refrain->render_value('parent_work');
		$options{title} = $repo->html_phrase('render_refrain_browse_parent_missing', parent => $parent_work_dom);
		$options{content} = $repo->html_phrase('render_refrain_browse_parent_missing', parent => $parent_work_dom);
	}
	else
	{
		my $flags = { host => 0 };
		my %fragments;

		my $host = $repo->call('work_host', $parent);
		if ($host)
		{
			$flags->{host} = 1;
			$fragments{host_box} = $repo->call('render_refrain_browse_render_host_box', $refrain, $parent, $host);
		}

		#insert types into fragments (they're all DOM)
		foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }

		$options{title} = $parent->render_citation('refrain_view_parent_boxtitle'),
		$options{content} = $parent->render_citation('refrain_view_work_boxcontent', %fragments, flags => $flags);
	}

	return EPrints::Box::render(%options);
};

$c->{render_refrain_browse_render_host_box} = sub
{
	my ($refrain, $parent, $host) = @_;
	my $repo = $refrain->repository;

	#this box needs a unique id for javascript to control it; construct it from these parts
	my @id_parts = (
		$refrain->value('refrain_id'), $refrain->value('instance_number'),
		$parent->value('work_id'), $parent->value('instance_number'),
		$host->value('work_id'),$host->value('instance_number')
	);

	my %options = (
			id => 'hostbox_' .  join('-',@id_parts),
			content => $host->render_citation('refrain_view_work_boxcontent',flags => {}),
			title => $host->render_citation('refrain_view_host_boxtitle'),
			session => $repo,
			collapsed => 1
		      );

	return EPrints::Box::render(%options);
}
