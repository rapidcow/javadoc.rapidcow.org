package Local::Plugin::DataFile;

use 5.006;
use strict;
use warnings;
use parent qw(Template::Plugin);

use File::Spec;
use Local::Data::MiniScheme qw(read_datum);

=head1 NAME

Local::Plugin::DataFile - load structured data

=head1 SYNOPSIS

  [% USE DataFile("trivnote/libexpr/rel-info.scm") %]

=head1 ROUTINES

=over

=item B<new($context, $file)>

read file!  assumes scheme files; other files are not supported.

=cut

sub new
{
	my ($class, $context, $file) = @_;

	my $dataroot = $context->stash->get([ 'D', 0, 'data', 0 ]);
	defined $dataroot or die "E: parameter \`data' unset\n";

	my $datafile = File::Spec->catfile($dataroot, $file);
	open my $fh, '<', $datafile or die "E: open($file): $!\n";
	my $root = read_datum($fh);

	close $fh or die "E: close($file): $!\n";
	bless { root => $root }, $class;
}

=item B<root()>

the top-level node: this is a scheme datum for C<*.scm> files.

=back

=cut

sub root
{
	$_[0]{root};
}

1;
