package Local::Data::MiniScheme;

use 5.006;
use strict;
use warnings;
use parent qw(Exporter);

use IO::Handle;
use Scalar::Util qw(blessed refaddr);
use Socket qw(LF);
use constant SX_NIL  => 1;
use constant SX_CONS => 2;
use constant SX_DOT  => 3;
use constant SX_SCALAR => 4;
use constant SX_SYMBOL => 5;

# nil is false (so `#f' works); everything else is true.
# '0+' keeps == comparing identity instead of truth values.
use overload
	'bool' => sub { $_[0]{tag} != SX_NIL },
	'0+'   => sub { refaddr $_[0] },
	'""'   => sub {
		my $tag = $_[0]{tag};
		$tag == SX_SCALAR || $tag == SX_SYMBOL ? $_[0]{value} :
		$tag == SX_NIL ? "" : sprintf "%s(0x%x)", __PACKAGE__, refaddr $_[0];
	},
	fallback => 1;

our @EXPORT_OK = qw(nil cons str sym read_datum);

# state was introduced in v5.10
# until we pin that, this might be better...
BEGIN {
	my $nil =
		bless { tag => SX_NIL }, __PACKAGE__;

	sub nil ()
	{
		$nil;
	}
}

BEGIN {
	my $dot =
		bless { tag => SX_DOT }, __PACKAGE__;

	sub dot ()
	{
		$dot;
	}
}

sub cons ($$)
{
	bless {
		tag => SX_CONS,
		car => $_[0],
		cdr => $_[1],
	}, __PACKAGE__;
}

sub str ($)
{
	bless {
		tag => SX_SCALAR,
		value => $_[0],
	}, __PACKAGE__;
}

{
	my %tab;

	sub sym ($)
	{
		if (exists $tab{ $_[0] }) {
			return $tab{ $_[0] };
		}
		$tab{ $_[0] } = bless {
			tag => SX_SYMBOL,
			value => $_[0],
		}, __PACKAGE__;

	}
}

sub read_datum
{
	local $/;
	my ($fh, $bg) = @_;
	my ($v, $w);
	my $sb;
V:	while (defined( $v = $fh->getc() )) {
		if ($v =~ /[[:space:]]/) {
			next V;
		}
		if ($v eq ';') {
			$/ = LF;
			if (!defined $fh->getline()) {
				last V;
			}
			next V;
		}
		if ($v eq '.') {
			if (!defined( $w = $fh->getc() )) {
				$fh->error ? last V : return dot();
			}
			else {
				if ($w =~ /[[:space:]\(\)"\|;]/) {
					$fh->ungetc(ord $w);
					return dot();
				}
				if (defined( $w = read_plain($fh, $sb = "$v$w") )) {
					$fh->ungetc(ord $w);
				}
				return str($sb);
			}
		}
		if ($v eq '(') {
			my ($o, @q, $e);
			my $sg = 0;
			while (defined( $o = read_datum($fh, 1) )) {
				if ($sg == 0) {
					if ($o == dot()) {
						@q or die "read_datum: `.' too early\n";
						$sg++;
					} else {
						push @q, $o;
					}
				}
				elsif ($sg == 1) {
					if ($o == dot()) {
							die "read_datum: double `.'
";
						}
					push @q, $o;
					$sg++;
				}
				elsif ($sg == 2) {
					die "read_datum: too many tails\n";
				}
			}
			if ($sg == 0) {
				$e = nil();
			}
			elsif ($sg == 2) {
				$e = pop @q;
			}
			else {
				die "read_datum: `.' who?\n"
			}
			return !@q ? nil() : do {
				my $p = cons(pop @q, $e);
				while (@q) {
					$p = cons(pop @q, $p);
				}
				$p;
			};
		}
		if ($v eq ')') {
			$bg or die "read_datum: unexpected `)'\n";
			return;
		}
		$sb = "";
		if ($v eq '"') {
			$/ = '"';
P:			while (defined( $v = $fh->getc() )) {
				last P if $v eq '"';
				$v ne "\\" or die "read_datum: no escape plz :(\n";
				$sb .= $v;
			}
			last V if $fh->error;
			return str($sb);
		}
		if (defined( $w = read_plain($fh, $sb = "$v") )) {
			$fh->ungetc(ord $w);
		}
		return 1 if $sb eq '#t';
		return nil() if $sb eq '#f';
		return $v =~ /[[:digit:]]/ ? str($sb) : sym($sb);
	}
	!$fh->error or die "read_datum: read error\n";
	!$bg or die "read_datum: unterminated list\n";
	return;
}

sub read_plain
{
	my ($fh) = @_;
	my $sbp = \$_[1];
	my $v;

P:	while (defined( $v = $fh->getc() )) {
		if ($v =~ /[[:space:]\(\)"\|;]/) {
			last P;
		}
		$$sbp .= $v;
	}
	return $v;
}

# Is $_[0] a datum with the given tag?
sub is_a
{
	blessed $_[0] && $_[0]->isa(__PACKAGE__) && $_[0]{tag} == $_[1];
}

# Proper list -> \@array of its elements.
sub list
{
	my ($p) = @_;
	my @a;
	while (is_a($p, SX_CONS)) {
		push @a, $p->{car};
		$p = $p->{cdr};
	}
	is_a($p, SX_NIL) or die "list: not a proper list\n";
	\@a;
}

# Alist (proper list of pairs) -> \%hash of cdr's keyed by car's value.
# First entry wins; keys that are not a symbol or scalar are skipped.
# Symbol/scalar cdr's are unwrapped into plain strings (so that they
# play nicely with TT's string vmethods); anything else is left as is.
sub attr
{
	my %h;
	for my $e (@{ $_[0]->list }) {
		is_a($e, SX_CONS) or die "attr: not an alist\n";
		my $k = $e->{car};
		is_a($k, SX_SYMBOL) || is_a($k, SX_SCALAR) or next;
		my $v = $e->{cdr};
		$v = $v->{value} if is_a($v, SX_SYMBOL) || is_a($v, SX_SCALAR);
		$h{ $k->{value} } = $v
			unless exists $h{ $k->{value} };
	}
	\%h;
}

1;
