
$c->{abstract_work_summary_page_metadata} = [qw(
title
generic_descriptor
)];

$c->{work_summary_page_metadata} = [qw(
manuscript_collocation
other_manuscript_data
date_description
authors
author_commentary
edition
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
)];

$c->{medmus_render_work} = sub
{
	my ($work) = @_;

	my $repo = $work->repository;
	my $xml = $repo->xml;
	my $frag = $xml->create_document_fragment;
	my %fragments = ();
	my $flags = {};

	#generate list of work instances within the abstract work of this instance
	my $siblings = $repo->call('all_instances', $repo, 'work', $work->value('work_id'));
	my $sibling_list = $xml->create_element('ul');

	foreach my $w (@{$siblings})
	{
		my $li = $xml->create_element('li');
		$sibling_list->appendChild($li);
		$li->appendChild($w->render_citation_link('manuscript'));
	}
	$fragments{work_instances} = $sibling_list;

	#generate host work link
	if ($work->value('host_work_id'))
	{
		my $host = $repo->call('instance_by_id', $repo, 'work', $work->value('host_work_id'), $work->value('host_work_instance'));
		if ($host)
		{
			my $frag = $xml->create_document_fragment;

			$frag->appendChild($host->render_citation_link('brief'));

			if ($work->is_set('location_in_host'))
			{
				$frag->appendChild($xml->create_text_node(' ['));
				$frag->appendChild($work->render_value('location_in_host'));
				$frag->appendChild($xml->create_text_node(']'));
			}
#			$frag->appendChild($xml->create_text_node(' ('));
#			$frag->appendChild($host->render_citation_link('id_and_instance'));
#			$frag->appendChild($xml->create_text_node(')'));
			
			$flags->{host} = 1;
			$fragments{host_work} = $frag; 
		}

	}

	#generated hosted works list
	my $hosted = $repo->call('hosted_works', $work);
	if (scalar @{$hosted})
	{
		my $ul = $xml->create_element('ul');
		foreach my $w (@{$hosted})
		{
			my $li = $xml->create_element('li');
			$ul->appendChild($li);
			$li->appendChild($w->render_citation_link('id_instance_text'));
		}
		$flags->{hosted} = 1;
		$fragments{hosted_works} = $ul; 
	}

	#generate list of refrains in this work and hosted works
	my $refrains = $repo->call('refrains_in_work', $work);
	my $refrains_dl = $xml->create_element('dl');
	foreach my $r (@{$refrains})
	{
		$refrains_dl->appendChild($r->render_citation_link('id_text_dl'));
	}
	$fragments{refrains} = $refrains_dl; 

	#insert types into fragments (they're all DOM)
	foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }
	#render work info in a box
	$frag->appendChild($work->render_citation('work_summary_page', %fragments, flags => $flags));

	return $frag;
};


$c->{abstract_refrain_summary_page_metadata} = [qw(
refrain_id
abstract_text
linker_number
)];

$c->{refrain_summary_page_metadata} = [qw(
reading_texts

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

manuscript_collocation
other_manuscript_data

other_refrain_data
parent_work

)];
$c->{medmus_render_refrain} = sub
{
	my ($refrain, $readingid_to_highlight) = @_;

	my $repo = $refrain->repository;
	my $xml = $repo->xml;
	my $frag = $xml->create_document_fragment;

	my %fragments = ();
	my $flags = {};

	#generate list of refrain instances within the abstract refrain of this instance
	my $siblings = $repo->call('all_instances', $repo, 'refrain', $refrain->value('refrain_id'));
	my $sibling_list = $xml->create_element('ul');

	foreach my $w (@{$siblings})
	{
		my $li = $xml->create_element('li');
		$sibling_list->appendChild($li);
		$li->appendChild($w->render_citation_link('manuscript'));
	}
	$fragments{refrain_instances} = $sibling_list;

	$flags->{music_img} = 0;
	my @docs = $refrain->get_all_documents;

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
	#render refrain info in a box
	$frag->appendChild($refrain->render_citation('refrain_summary_page', %fragments, flags => $flags));

	return $frag;
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
	if ($type eq 'work')
	{
		$page->appendChild($repository->call('medmus_render_work', $eprint));
	}

	my $links = $repository->xml()->create_document_fragment();

	return( $page, $title, $links );
};


