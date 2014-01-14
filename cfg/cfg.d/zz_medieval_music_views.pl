
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
		my $flags = {};
		my %fragments = ();

		my $parents = $repo->call('refrain_parents', $instance);

		my $box_title = $instance->render_citation('refrain_view_refrain_boxtitle');


		my $parent_frag = $xml->create_document_fragment;

		foreach my $parent (@{$parents})
		{
			my %fragments;
			my $flags = { host => 0};

			my $host = $repo->call('work_host', $parent);

			if ($host)
			{
				my $hostbox_title = $host->render_citation('refrain_view_host_boxtitle');
				my $hostbox_content = $host->render_citation('refrain_view_work_boxcontent',flags => {});
				my @id_parts = (
					$instance->value('refrain_id'),
					$instance->value('instance_number'),
					$parent->value('work_id'),
					$parent->value('instance_number'),
					$host->value('work_id'),
					$host->value('instance_number')
				);

				my %options = (
					id => 'hostbox_' .  join('/',@id_parts),
					content => $hostbox_content,
					title => $hostbox_title,
					session => $repo,
					collapsed => 1
				);

				$fragments{host_box} = EPrints::Box::render(%options);
				$flags->{host} = 1;
			}

			my $parentbox_title = $parent->render_citation('refrain_view_parent_boxtitle');
			#insert types into fragments (they're all DOM)
			foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }
			my $parentbox_content = $parent->render_citation('refrain_view_work_boxcontent', %fragments, flags => $flags);

			my @id_parts = (
				$instance->value('refrain_id'),
				$instance->value('instance_number'),
				$parent->value('work_id'),
				$parent->value('instance_number'),
			);

			my %options = (
				id => 'parentbox_' .  join('/',@id_parts),
				content => $parentbox_content,
				title => $parentbox_title,
				session => $repo,
				collapsed => 1
			);

			$parent_frag->appendChild(EPrints::Box::render(%options));
		}

		my $p_flags = {parents => 1};
		my %p_fragments = (parent_boxes => $parent_frag);


		my $refrainbox_title = $instance->render_citation('refrain_view_refrain_boxtitle');
		#insert types into fragments (they're all DOM)
		foreach my $key ( keys %p_fragments ) { $p_fragments{$key} = [ $p_fragments{$key}, "XHTML" ]; }
		my $refrainbox_content = $instance->render_citation('refrain_view_refrain_boxcontent', %p_fragments, flags => $p_flags);

		my @id_parts = (
			$instance->value('refrain_id'),
			$instance->value('instance_number'),
		);

		my %options = (
			id => 'refrainbox_' .  join('/',@id_parts),
			content => $refrainbox_content,
			title => $refrainbox_title,
			session => $repo,
			collapsed => 0 
		);

		$frag->appendChild(EPrints::Box::render(%options));
	}




	return $frag;
};

