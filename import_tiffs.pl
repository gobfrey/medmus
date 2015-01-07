#!/usr/bin/perl -I/usr/share/eprints/perl_lib

use strict;
use warnings;

use utf8;

use Data::Dumper;
use Unicode::Escape qw(escape unescape);
use Encode::Escape::Unicode;
use Text::Unidecode;


binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


use EPrints;
use Text::Iconv;
my $conv = Text::Iconv->new('utf8','utf16');

my $repo_id = 'medmus';
my $img_dir = '/home/eprints/micro-repositories/instances/medmus/TIFS';


my $ep = EPrints->new;
my $repo = $ep->repository('medmus');

die unless $repo;

my $files = {};

foreach my $file (<$img_dir/*>)
{
	my $cmp = compval_fs($file);
	die "Filename collision for $cmp\n" if $files->{$cmp};
	$files->{$cmp} = $file;
}

my $problems = 0;
$repo->dataset('eprint')->search->map(
sub
{
	my( $repo, $ds, $eprint ) = @_;

	return unless $eprint->is_set('image_file');
	my $image_file = $eprint->value('image_file');

	my $cmp = compval_db($img_dir . '/' . $image_file . '.png');
	my $filename = $files->{$cmp};
	if (!$filename)
	{
		$problems++;
		print STDERR $eprint->value('refrain_id') . '/' . $eprint->value('instance_number') . "No file for $image_file";
		return;
	}

	if (-e $files->{$cmp})
	{
		my $doc = $eprint->create_subdataobj( "documents" );

		my $file = $doc->add_file($files->{$cmp}, $filename);
		$file->set_value('mime_type', $repo->call('guess_doc_type', $repo, $files->{$cmp}));
		$file->commit;
		$doc->set_main($file);
		$doc->set_value('format', 'image');
		$doc->commit;
		$eprint->commit;	
	}
	else
	{
		$problems++;
		print STDERR "Cannot open $image_file with cmp of $cmp\n";
	}
});

print STDERR "$problems problems\n";


sub full_path
{
	my ($filename) = @_;

	return $img_dir . '/' . $filename . '.tif';

}



#strip out utf8
sub compval_db
{
	my ($str) = @_;
	my $v = $str;
	chomp $v; #belt and braces

	$v =~ s/vdB/vdb/;

	return unidecode($v);
}
sub compval_fs
{
	my ($str) = @_;
	my $v = $str;

	chomp $v;

	$v =~ s/[^0-9a-zA-Z\. \/]//g;

	$v =~ s/vdB/vdb/;

	return $v;
}

