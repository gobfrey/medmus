#!/usr/bin/perl

use strict;
use warnings;

use Text::CSV_XS;
use XML::LibXML;

use utf8;
use encoding qw(utf8);
binmode STDOUT, ":utf8"; 
binmode STDERR, ":utf8"; 

my $works_file = 'new_works5.csv';
my $refrains_file = 'new_refrains4.csv';

die "cannot find files\n" unless (-e $works_file && -e $refrains_file);

my $objects = []; #extract the works and refrains to here

my $columns = initialise_columns(); #data about columns

my $tables;
$tables->{works} = load_data($works_file);
$tables->{refrains} = load_data($refrains_file);

my $heading_maps;
$heading_maps->{works} = initialise_heading_map($tables->{works}); #mapping of table heading to column index
$heading_maps->{refrains} = initialise_heading_map($tables->{refrains});


foreach my $row ( 1 .. $#{$tables->{refrains}} )
{
	next unless val('refrains','Ref Number',$row);


	my $refrain = {
		medmus_type => 'refrain'
	}; #each row is a refrain
	push @{$objects}, $refrain;

	process_generic_fields($refrain, 'refrains', $row);

	#manuscript collocation
	my $val = val('refrains', 'Manuscript Collocation', $row);
	my ($manuscript, $location) = split(/,\s*/,$val,2);

	$refrain->{manuscript_id} = $manuscript;
	$refrain->{manuscript_location} = $location;

	#reading texts
	foreach my $c (@{$columns->{refrains}->{complex_cols}})
	{
		my $val = val('refrains',$c, $row);
		next unless $val;

		if ($c eq 'Derived Reading Text')
		{
			push @{$refrain->{reading_texts}}, { text =>  $val };
		}
		elsif ($c =~ m/^Derived Reading Text \((.*)\)/)
		{
			my $position = $1;

			my $reading = {
				text => $val,
			};

			if ($c eq 'Derived Reading Text (Refrain 1 [sur l\'incipit français])')
			{
				$reading->{refrain} = '1_slf';

			}
			elsif ($position =~ m/;/) #two part position			
			{
				foreach my $part (split(/\s*;\s*/, $position))
				{
					if ($part =~ m/[Rr]efrain\s*(.*)/)
					{
						my $r = lc($1);
						$r =~ s/\s//g; #remove spaces
						$reading->{refrain} = lc($r);
					}
					elsif ($part =~ m/st\.\s*([0-9]+)/)
					{
						$reading->{stanza} = lc($1);
					}
					elsif ($part =~ m/envoi\s*([I]*)/)
					{
						$reading->{envoi} = lc($1);
					}
					elsif ($part eq 'Fatras')
					{
						#do nothing?
					}
					else
					{
						die "unrecognised part in $position\n";
					}
					
				}
			}
			elsif ($position =~ m/^[Rr]efrain\s*(.*)/)
			{
				$reading->{refrain} = lc($1);
			}
			else
			{
				$reading->{refrain} = lc($position);
			}

			push @{$refrain->{reading_texts}}, $reading;

		}
	}
}

#process the rows
foreach my $row ( 1 .. $#{$tables->{works}} )
{

	next unless val('works','ID', $row); #skip if there's no ID -- it's probably a blank line

	my $work = {
		medmus_type => 'work'
	}; #each row is a reading
	push @{$objects}, $work;
	
	process_generic_fields($work, 'works', $row);

	#manuscript collocation
	my $val = val('works', 'Manuscript Collocation', $row);
	my ($manuscript, $location) = split(/,\s*/,$val,2);

	$work->{manuscript_id} = $manuscript;
	$work->{manuscript_location} = $location;


	#remove whitespace from work_id
	$work->{'work_id'} =~ s/\s//g;
	$work->{'host_work_id'} =~ s/\s//g if $work->{'host_work_id'};


	#authors
	my $val = val('works','Authors', $row);
	my @author_strings = split(/\s*;\s*/, $val);
	my $authors = [];
	foreach my $author_string (@author_strings)
	{
		my $author = {};
		#grab the bit after the name that's in brackets (if present)
		if ($author_string =~ m/^(.*)\((.*)\)(.*)$/)
		{
			$author->{locations} = $2;
			$author_string = $1 . ' ' . $3; #preserve question marks on either side of the bracketed bit 
		}

		#if there's a question mark, it's an assumption
		if ($author_string =~ m/^(.*)\?\s*$/)
		{
			$author->{assumed} = 'TRUE';
			$author_string = $1;
		}
		else
		{
			$author->{assumed} = 'FALSE';
		}
		
		#strip leading and trailing space
		$author_string =~ s/^\s*//;
		$author_string =~ s/\s*$//;

		#whatever is left is the name
		$author->{name} = $author_string;

		push @{$authors}, $author;
	}
	$work->{authors} = $authors;
}


#data is the data_object being built
#table is 'works' or 'refrains'
#row is the row number we're currently in
sub process_generic_fields
{
	my ($data, $table, $row) = @_;

	#simple values -- just copy in
	while ( my ($heading, $tagname) = each %{$columns->{$table}->{simple}} )
	{
		my $val = val($table,$heading, $row);

		my $single_with_semicolon = {
			'Abstract Master Text' => 1,
			'Title' => 1,
		};

		if ($val)
		{
			if (
				$val =~ m/;/
				&& !$single_with_semicolon->{$heading}
			)
			{
				die "$table: Semicolon in singular field $heading, row $row\n";
			}
			$data->{$tagname} = $val;
		}
	}

	#simple multiple values -- just copy in
	while ( my ($heading, $tagname) = each %{$columns->{$table}->{multiple}} )
	{
		my $val = val($table,$heading, $row);
		if (defined $val)
		{
			#bad data in source(?)
			$val =~ s/3 \(F-Pn fr. 25566\)/3/g if $heading eq 'Number of parts';

			my @val = split(/\s*;\s*/,$val);
			#problem data

			$data->{$tagname} = [@val] if scalar @val;
		}
	}

	#set values
	while ( my ($heading, $col) = each %{$columns->{$table}->{set}} )
	{
		my $val = val($table,$heading, $row);
		next unless $val;
		my $value; #this is what will be set

		if ($col->{multiple})
		{
			my @val = split(/\s*;\s*/,$val);
			foreach my $k (@val)
			{
				my $v = $col->{options}->{$k};
				if (!$v)
				{
					die "Unrecognised set member $k in column $heading, row $row\n";
				}
				push @{$value}, $v;
			}
		}
		else
		{
			my $v = $col->{options}->{$val};
			if (!$v)
			{
				die "Unrecognised set member $val in column $heading, row $row\n";
			}
			$value = $v;
		}

		$data->{$col->{tagname}} = $value;
	}


}


output_epxml($objects);

sub output_epxml
{
	my ($arr) = @_;

	my $doc = XML::LibXML::Document->new();
	my $eprints = $doc->createElement('eprints');

	foreach my $work (@{$arr})
	{
		my $eprint = $doc->createElement('eprint');
		$eprints->appendChild($eprint);

		foreach my $tagname (keys %{$work})
		{
			if ($work->{$tagname})
			{
				$eprint->appendChild(construct_val($tagname, $work->{$tagname}, $doc));
			}
		}
	}

	print $eprints->toString;
}

sub construct_val
{
	my ($tagname, $val, $doc) = @_;

	my $el = $doc->createElement($tagname);
	if (!ref $val)
	{
		#exception for single questionmark in the number_of_stanzas tag
		return $el if ($columns->{works}->{strip_questionmark_vals}->{$tagname} and $val eq '?');

		$el->appendText($val);
		return $el;
	}

	if (ref $val eq 'ARRAY')
	{
		foreach my $v (@{$val})
		{
			my $item = $doc->createElement('item');
			$el->appendChild($item);
			if (!ref $v)
			{
				$item->appendText($v);
			}
			elsif (ref $v eq 'HASH')
			{
				foreach my $k (keys %{$v})
				{
					next unless $v->{$k}; #ignore empty elements;
					my $t = $doc->createElement($k);
					$t->appendText($v->{$k});
					$item->appendChild($t);
				}
			}
			else
			{
				die "Unexpected content of array when generating XML\n";
			}
		}
	}
	return $el;
}


sub val
{
	my ($table, $heading, $row) = @_;

	if (!defined $heading_maps->{$table}->{$heading})
	{
		die "Undefined $heading in $table table\n";

	}
	return $tables->{$table}->[$row]->[$heading_maps->{$table}->{$heading}];
}


sub load_data
{
	my ($filename) = @_;

	use Text::CSV_XS;
	my $csv = Text::CSV_XS->new ({ binary => 1 });

	open my $fh, "<:encoding(utf8)", $filename or die "$filename: $!";

	my $spreadsheet = $csv->getline_all($fh);
	return $spreadsheet;
}


sub initialise_columns
{

	my $c = {};

	$c->{works}->{simple} = 
	{
		"ID" => 'work_id',
		"Instances of works" => 'instance_number',
		"Title" => 'title',
		"Number of stanzas" => 'number_of_stanzas',
		"Number of envois" => 'number_of_envois',
		"RS Index" => 'rs_index',
		"T Index (Motets)" => 't_index_motets',
		"T Index (Songs)" => 't_index_songs',
		"Lu Index" => 'lu_index',
		"vdB Index (Rondeaux)" => 'vdb_index',
		"Number of parts" => 'number_of_parts',
		"Host work ID" => 'host_work_id',
		"Host Work Instance" => 'host_work_instance',
		"Host Work Location" => 'location_in_host',
	};

	$c->{refrains}->{multiple} =
	{
		'Singer' => 'singer',
		'Destinataire' => 'audience',
		'Fonction' => 'function',
		'Marque de chant précédant le refrain' => 'preceeding_lyric',
		'Marque de chant suivant le refrain' => 'succeeding_lyric',
		'Marque de discours' => 'mark_of_discourse',
		'Métrique' => 'meter',
		'Other Refrain data' => 'other_refrain_data',
		'Other Manuscript Data' => 'other_manuscript_data',
		'Image File' => 'image_file',
	};

	$c->{refrains}->{simple} = 
	{
		'Parent Work (ID)' => 'parent_work_id',
		'Parent Work (Instance)' => 'parent_work_instance',
		'Parent Work (Location)' => 'location_in_parent',
		'Ref Number' => 'refrain_id',
		'Instance Number' => 'instance_number',
		'Linker Number' => 'linker_number',
		'Abstract Master Text' => 'abstract_text',
#		'Occurance Number' => 'occurence_number',
#		'Host Work' => '',
		'Circonstances' => 'circumstance',
#		'Manuscript Number' => '',
		'Musical structure' => 'musical_structure',
	};

	$c->{refrains}->{set} = 
	{
		'Refrain Location' =>
		{
			tagname => 'refrain_location',
			multiple => 1,
			options => {
				'Enté' => 'enté',
				'Enté interne' => 'enté_interne',
				'Fin de  strophe' => 'fin_de_strophe',
				'Fin de stophe' => 'fin_de_strophe',
				'Fin de strophe' => 'fin_de_strophe',
				'Final' => 'final',
				'Initial' => 'initial',
				'Interne' => 'interne',
			}
		},
	};


	$c->{refrains}->{complex_cols} = 
	[
		'Image File',
		'Manuscript Collocation',
		'Derived Reading Text',
		'Derived Reading Text (Refrain 1 [sur l\'incipit français])',
		'Derived Reading Text (Refrain 1)',
		'Derived Reading Text (Refrain 2)',
		'Derived Reading Text (Refrain 3)',
		'Derived Reading Text (Refrain 4)',
		'Derived Reading Text (Refrain 5)',
		'Derived Reading Text (Refrain 6)',
		'Derived Reading Text (Refrain triplum)',
		'Derived Reading Text (Refrain duplum)',
		'Derived Reading Text (Refrain teneur)',
		'Derived Reading Text (Initial)',
		'Derived Reading Text (Final)',
		'Derived Reading Text (st. 1; refrain enté)',
		'Derived Reading Text (st. 1; refrain initial)',
		'Derived Reading Text (st. 1; refrain interne)',
		'Derived Reading Text (st. 1 ; refrain interne 2)',
		'Derived Reading Text (st. 1 ; refrain final)',
		'Derived Reading Text (st. 2 ; refrain enté)',
		'Derived Reading Text (st. 2 ; refrain initial)',
		'Derived Reading Text (st. 2 ; refrain interne)',
		'Derived Reading Text (st. 2 ; refrain interne 2)',
		'Derived Reading Text (st. 2 ; refrain final)',
		'Derived Reading Text (st. 3 ; refrain initial)',
		'Derived Reading Text (st. 3 ; refrain interne)',
		'Derived Reading Text (st. 3 ; refrain interne 2)',
		'Derived Reading Text (st. 3 ; refrain final)',
		'Derived Reading Text (st. 4 ; refrain initial)',
		'Derived Reading Text (st. 4 ; refrain interne)',
		'Derived Reading Text (st. 4 ; refrain interne 2)',
		'Derived Reading Text (st. 4 ; refrain final)',
		'Derived Reading Text (st. 5 ; refrain initial)',
		'Derived Reading Text (st. 5 ; refrain interne)',
		'Derived Reading Text (st. 5 ; refrain interne 2)',
		'Derived Reading Text (st. 5 ; refrain final)',
		'Derived Reading Text (st. 6 ; refrain initial)',
		'Derived Reading Text (st. 6 ; refrain interne)',
		'Derived Reading Text (st. 6 ; refrain interne 2)',
		'Derived Reading Text (st. 6 ; refrain final)',
		'Derived Reading Text (st. 7 ; refrain initial)',
		'Derived Reading Text (st. 7 ; refrain interne)',
		'Derived Reading Text (st. 7 ; refrain interne 2)',
		'Derived Reading Text (st. 7 ; refrain final)',
		'Derived Reading Text (st. 8 ; refrain initial)',
		'Derived Reading Text (st. 8 ; refrain interne)',
		'Derived Reading Text (st. 8 ; refrain interne 2)',
		'Derived Reading Text (st. 8 ; refrain final)',
		'Derived Reading Text (st. 9 ; refrain initial)',
		'Derived Reading Text (st. 9 ; refrain interne)',
		'Derived Reading Text (st. 9 ; refrain interne 2)',
		'Derived Reading Text (st. 9 ; refrain final)',
		'Derived Reading Text (st. 10 ; refrain initial)',
		'Derived Reading Text (st. 10 ; refrain final)',
		'Derived Reading Text (st. 11 ; refrain final)',
		'Derived Reading Text (st. 12 ; refrain final)',
		'Derived Reading Text (st. 13 ; refrain final)',
		'Derived Reading Text (st. 14 ; refrain final)',
		'Derived Reading Text (st. 15 ; refrain final)',
		'Derived Reading Text (st. 16 ; refrain final)',
		'Derived Reading Text (st. 17 ; refrain final)',
		'Derived Reading Text (st. 18 ; refrain final)',
		'Derived Reading Text (st. 19 ; refrain final)',
		'Derived Reading Text (st. 20 ; refrain final)',
		'Derived Reading Text (st. 21 ; refrain final)',
		'Derived Reading Text (st. 22 ; refrain final)',
		'Derived Reading Text (st. 23 ; refrain final)',
		'Derived Reading Text (st. 24 ; refrain final)',
		'Derived Reading Text (st. 25 ; refrain final)',
		'Derived Reading Text (envoi I ; refrain final)',
		'Derived Reading Text (envoi II ; refrain initial)',
		'Derived Reading Text (envoi II ; refrain final)',
		'Derived Reading Text (Refrain 1 ; Fatras)',
		'Derived Reading Text (Refrain 2 ; Fatras)',
	];

	$c->{works}->{multiple} = 
	{
		"Other data" => 'other_data',
		"MW Index" => 'mw_index',
		"L Index" => 'l_index',
		"Edition" => 'edition',
		"Date" => 'date_description',
		"Generic Descriptor" => 'generic_descriptor',
	};

	$c->{works}->{set} = 
	{
		"Primary Language" =>
		{
			tagname => 'primary_language',
			options =>
			{
				'Langue d\'oïl' => 'langue_d_oil',
				'Latin' => 'latin'
			},
			multiple => 0
		},
		"Secondary Language" =>
		{
			tagname => 'secondary_language',
			options =>
			{
				'Langue d\'oïl' => 'langue_d_oil',
				'Latin' => 'latin'
			},
			multiple => 0
		},
		"Style of discourse" => 
		{
			tagname => 'style_of_discourse',
			options =>
			{
				'Vers' => 'vers',
				'Prose asonancée' => 'prose_asonancee',
				'Prose' => 'prose',
			},
			multiple => 1
		},
		"Voice in the Polyphony" =>
		{
			tagname => 'voice_in_polyphony',
			options =>
			{
				Duplum => 'duplum',
				Triplum => 'triplum',
				Quadruplum => 'quadruplum',
				Motet => 'motet',
				Teneur => 'teneur',
			},
			multiple => 1,
		}
	};

	$c->{works}->{complex_cols} = 
	{
		"Authors" => 'authors',
	};

	#these fields may contain a '?' -- treat as undef
	$c->{works}->{strip_questionmark_vals} = 
	{
		'number_of_stanzas' => 1,
	};

	return $c;
}

#populate heading_map
sub initialise_heading_map
{
	my ($sheet) = @_;
	my $heading_map = {};

	foreach my $col (0 .. $#{$sheet->[0]})
	{
		my $heading = $sheet->[0]->[$col];
		if ($heading)
		{
			$heading_map->{$heading} = $col
		}
	}
	return $heading_map;
};



