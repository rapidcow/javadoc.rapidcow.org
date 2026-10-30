package RdKw::WwW::GenGenLib;

=head1 NAME

RdKw::WwW::GenGenLib - general-purpose WwW-generation library

As an aside, I do think that this is the right way to
write World-wide Web, since the second "w" is part of
a compound word, not a word itself. ;)

=cut

use strict;
use 5.006;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT;
our @EXPORT_OK;

use URI ();
use URI::Escape qw(uri_unescape);

=head1 SUBS

All subs are exported straight to yur home.  Yum!

(With the exception of one; see below.)

=over

=item B<parse_base> \%D

Sanitize, normalize, and whine about user-supplied
I<base_url> and I<site_url>.

=cut

sub parse_base
{
	my ($D) = @_;
	my ($base_url, $site_url);
	my $Me = "parse_base";

	# site_url cannot be derived, so it is required.
	defined $D->{site_url} and $D->{site_url} ne ''
		or die "parse_base: missing site_url\n";
	$site_url = URI->new($D->{site_url});

	{
		my $proto = $site_url->scheme;
		unless (defined $proto and grep { lc($proto) eq $_ } qw( file http https )) {
			die "$Me: site_url has no file or www URI scheme: $D->{site_url}\n";
		}
	}

	if (defined $D->{base_url} and $D->{base_url} ne '') {
		$base_url = $D->{base_url};
		# Unlike before, an empty path is straight up assumed
		# to be explicitly unset by user.  So might as well...
		unless ($base_url =~ m!^/!) {
			die "$Me: base_url must begin with a slash\n";
		}
		unless ($site_url->path eq '' or $base_url eq $site_url->path) {
			# This is probably one of the more grave cases;
			# so report it thoroughly to the console.
			my $path = $site_url->path;
			die <<EUGH;
$Me: site_url has an nonempty path ($path), and
$Me: is inconsistent with base_url ($base_url)
EUGH
		}
	} else {
		$base_url = $site_url->path;
		if ($base_url eq '') {
			die <<EUGH;
$Me: base_url cannot be inferred from site_url,
$Me: as the latter has an empty path
EUGH
		}
	}

	$site_url->fragment(undef);
	$site_url->query(undef);
	$site_url->path('');

	# site_url will be blessed; but that's okay
	# with URI's overloaded stringification... :v
	$D->{base_url} = $base_url;
	$D->{site_url} = $site_url;
	# All is well
	1;
}

push @EXPORT, 'parse_base';

=item B<locate> \%D, I<base>, I<spec>

Implements the synonymous TT2 function.

=cut

sub locate {
	my ($D, $base, $spec) = @_;

	if ($spec =~ s!^//!!) {
		return join '', (
			$D->{site_url},
			$D->{base_url},
			$spec);
	}

	if ($spec =~ s!^/!!) {
		return join '', (
			$D->{base_url},
			$spec);
	}

	relapath($spec => $base);
}

push @EXPORT, 'locate';

=item B<relapath> I<path>, I<base>

Write a path to I<path> relative to I<base>.  It's as
simple as that.  Of course, like web browsers, there is
the notion of the "current directory".  That is, the
trailing slash will be honored, and the lack of one
will be taken to indicate an omissible filename.

Two conveniences on top of that:

=over

=item *

A leading C<.> segment on I<path> is dropped, once.  So
C<.> and C<./> both mean the root (as does the empty string),
and C<./x> means C<x>.  Only the first dot is special:
C<./.> and C<a/./b> keep the dot that comes later.

=item *

A C<..> is already a directory, so a lone trailing slash
after the last C<..> is redundant and is omitted: C<../..>
rather than C<../../>.  A second slash asks for it back
(C<../>).  Any subsequent slashes are idempotent.

=back

This subroutine is not exported by default.

=cut

sub relapath {
	my ($path, $base) = @_;
	#
	# (contributed by Anthropic Claude)
	# Done as a pre-processing step so that `.//'
	# leaves `/' behind, i.e., one empty segment
	# per extra slash.  (This is also so that a
	# `./' prefix serves as a no-op prefix---but
	# only when it is spelled as . and not %2F.)
	#
	$path =~ s!^[.](?:/|$)!!;
	my @path = split('/', $path, -1);
	my @base = split('/', $base, -1);

	my $comm = 0;
COMM:	while () {
		#
		# (adapted from Anthropic Claude's patch)
		# When the operands are related by being
		# strict sub-paths, only the last index we
		# visited was actually common, not where
		# $comm is at presently.  The one exception
		# being if we never checked any path at all
		# (i.e. $comm == 0, and one operand is root).
		#
		unless ($comm < @path) {
			--($comm) if $comm && $comm < @base;
			last COMM;
		}
		unless ($comm < @base) {
			--($comm) if $comm && $comm < @path;
			last COMM;
		}
		my $pathpart = uri_unescape ($path[$comm]);
		my $basepart = uri_unescape ($base[$comm]);
		last COMM if $pathpart ne $basepart;
	}
	continue {
		++($comm);
	}

	#
	# This accounts for the trailing slash in @base, where
	# we're "leaving" a directory with a single file whose
	# name is the empty string, e.g. ('dir', 'path', '').
	#
	# And of course Perl is forgiving when it comes to
	# @list x $NEGATIVE, but in the case where all paths
	# line up, make $upupup at least 0.
	#
	my $upupup = (@base - $comm || 1) - 1;
	#
	# The next bit is self-explanatory.  We just append the
	# non-common parts after the common part is over...
	# (again, trailing slash will be dealt with, if it ever
	# shows up in $path -- that will just be an empty
	# component concatenated with a bunch of "/"'s.)
	#
	my @rest = @path[$comm..$#path];
	#
	# (contributed by Anthropic Claude)
	# Only `..'s and empty segments: the first empty segment
	# is the trailing slash that `..' does not need.
	#
	pop @rest if $upupup && @rest && !grep { length } @rest;
	join '/', ('..') x $upupup, @rest;
}

push @EXPORT_OK, 'relapath';

=item B<read_make> I<file>

This reads user-configured B<MY/*.mk> files.
They're kind of like DOS-INI / GNU libconfini, but
well... dumber.  Namely, we implement no escapes,
and whitespaces are heartlessly stripped.  And
certainly no line continuation.  We also want to
see C<=>, which is admittedly unnecessary, but
that's what we call ourselves: read L<make(1))>-like
declarations.  Helps keep the mind sane. ;D

=cut

# This was initially written for `render', but i
# later realized this would be nice for ./configure
# idempotency on already-configured source trees.
#
# Even claude said so... ugh!  You're pure evil!
# I was thinking about getting away with un-DRY-ness
# .... DX
sub read_make
{
	local ($_, $.);
	my ($file) = @_;

	open my $fh, '<', $file or die "read_make: open <$file: $!\n";
	binmode $fh, ':encoding(UTF-8)';

	my %O;
	while (<$fh>) {
		next if /^\s*#/ or /^\s*$/;
		my ($k, $v) = split /=/, $_, 2;
		defined $v or die "read_make: $file line $.: no `='\n";
		$k =~ s/^\s+|\s+$//g;
		$v =~ s/^\s+|\s+$//g;
		$O{$k} = $v;
	}

	close $fh;
	%O;
}

push @EXPORT, 'read_make';

=item B<read_deps> I<file>

This is an ambitious one.  Essentially, we're trying
to propose a framework for a lean, but robost build
dependency specification.  This function itself doesn't
do much, but it reads/parses outgoing edges of what's
conceptually a I<dependency graph>.  Here's how.

=over

=item *

We have the reflexive node name called B<HAVE>.
This is a unique value; you cannot be Heisenberg.

=item *

Dependency B<NEED> is just normal dependency.
Its absence would cause any attempts at building
the target explode on the spot.  Such fellas are
called hard-dependency retronymically due to...

=item *

Soft-depedency B<WANT> conceptually means that the
transformation rule responsible for producing some
target from this node I<can> utilize this resource
but will degrade accordingly if it is absent.  In
practice, soft-dependencies are checked at configuration
time, and if it (or any of its hard-dependents) is
missing, it is removed from the dependency list,
optionally emitting a warning.

This makes it less of a dependency in the strict
sense and more of a suggestion to the human operator
that the build is less than ideal.

=back

This function returns a hash map:

   [%#
   # HAVE: ethan
   # WANT: art music
   # WANT: 2-draw
   # NEED: puterz!!!
   -%]
   # WANT: jork-off :,<

becomes

   {
      HAVE => "ethan",
      WANT => [ "art", "music", "2-draw" ],
      NEED => [ "puterz!!!" ],
   }

The dependency edge specification is terminated by
a blank line, or a line that does not look like
another header line (C</^# \S>).  For this reason,
you won't see my evil desires following the TT2
closing tag...

=cut

sub read_deps {
	local ($_, $.);
	my ($file) = @_;
	my $onit = 0;
	my $I = {};

	open my $fh, '<', $file or die "read_deps: open $file: $!\n";
	binmode $fh, ':encoding(UTF-8)';

	while (<$fh>) {
		chomp;
		# Common comment chars:
		#   #  (UNIX sh, scripting languages)
		#   ;  (BIND zone, DOS-INI, Lisp, ledger)
		#   *  (C89/ANSI/K&R /* ... */)
		#   // (C++, Java, C99 line-comment)
		#   "  (vimscript)
		#   '  (VBScript (aughhhhhh!!! >n<!))
		#   -- (lua)
		#   %  (TeX, lilypond)
		# A space is necessary both due to my
		# subjective aesthetics and preventing
		# false positives (e.g. a quoted string)
		if (/^\s*(?:#|;|\*|\/\/|"|'|--|%) (HAVE|WANT|NEED):/g) {
			my $type = $1;
			my @list = /\S+/g;
			$onit = 1;
			next unless @list;

			if ($type eq 'HAVE') {
				die "read_deps: $file line $.: You HAVE too many.\n"
					if @list > 1 or exists $I->{$type};
				$I->{HAVE} = $list[0];
			} else {
				push @{$I->{$type}}, @list;
			}
		}
		last if $onit and !/^# \S/;
	}

	close $fh;
	%$I;
}

push @EXPORT, 'read_deps';

=back

=head1 SEE ALSO

The original experiment in
C<our/cooper/www>, file
C<gen/lib/Local/WWW/Cooper.pm>.

=cut

1;
