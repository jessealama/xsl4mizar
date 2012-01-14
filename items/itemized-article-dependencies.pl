#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename);
use Getopt::Long;
use Pod::Usage;

my $stylesheet_home = undef;
my $script_home = undef;
my $verbose = 0;
my $man = 0;
my $help = 0;

GetOptions('help|?' => \$help,
           'man' => \$man,
           'verbose'  => \$verbose,
	   'stylesheet-home=s' => \$stylesheet_home,
	   'script-home=s', \$script_home)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(1) if (scalar @ARGV != 1);

if (defined $stylesheet_home) {
  if (! -e $stylesheet_home) {
    die 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets does not exist.', "\n";
  }
  if (! -d $stylesheet_home) {
    die 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.', "\n";
  }
} else {
  $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';
  if (! -e $stylesheet_home) {
    die 'Error: the default directory in which we look for stylesheets', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'does not exist.  Consider using the --stylesheet-home option.', "\n";
  }
  if (! -d $stylesheet_home) {
    die 'Error: the default directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.  Consider using the --stylesheet-home option.', "\n";
  }
}

if (defined $script_home) {
  if (! -e $script_home) {
    die 'Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for needed auxiliary scripts does not exist.', "\n";
  }
  if (! -d $script_home) {
    die 'Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for needed auxiliary is not actually a directory.', "\n";
  }
} else {
  $script_home = '/Users/alama/sources/mizar/xsl4mizar/items';
  if (! -e $script_home) {
    die 'Error: the default directory in which we look for needed auxiliary scripts', "\n", "\n", '  ', $script_home, "\n", "\n", 'does not exist.  Consider using the --script-home option.', "\n";
  }
  if (! -d $script_home) {
    die 'Error: the default directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.  Consider using the --script-home option.', "\n";
  }
}

my $article_dir = $ARGV[0];

unless (-d $article_dir) {
  die 'Error: ', $article_dir, ' is not a directory.', "\n";
}

my $article_basename = basename ($article_dir);

my %script_paths = ('map-ckbs.pl' => "${script_home}/map-ckbs.pl",
		    'dependencies.pl' => "${script_home}/dependencies.pl");

foreach my $script (keys %script_paths) {
  my $script_path = $script_paths{$script};
  if (! -e $script_path) {
    die 'Error: the needed auxiliary script', "\n", "\n", '  ', $script, "\n", "\n", 'does not exist at the expected location', "\n", "\n", '  ', $script_path, "\n";
  }
  if (! -r $script_path) {
    die 'Error: the needed auxiliary script', "\n", "\n", '  ', $script, "\n", "\n", 'at', "\n", "\n", '  ', $script_path, "\n", "\n", 'is unreadable.';
  }
  if (! -x $script_path) {
    die 'Error: the needed auxiliary script', "\n", "\n", '  ', $script, 'at', "\n", "\n", '  ', $script_path, 'is not executable.';
  }
}

my $map_ckb_script = $script_paths{'map-ckbs.pl'};
my @item_to_fragment_lines = `$map_ckb_script $article_dir`;

my ($item_to_fragment_exit_code, $item_to_fragment_message) = ($? >> 8, $!);
if ($item_to_fragment_exit_code != 0) {
  if (-z $map_ckb_err_file) {
    die 'Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", '(Curiously, the map-ckb script did not produce any error output.)';
  } elsif (! -r $map_ckb_err_file) {
    die 'Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", '(Curiously, we are unable to read the error output file of the map-ckb script.)';
  } else {
    print STDERR ('Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", 'Here is the error output produced by the map-ckb script:', "\n");
    print '----------------------------------------------------------------------', "\n";
    system ('cat', $map_ckb_err_file);
    print '----------------------------------------------------------------------', "\n";
    die;
  }
}

if (scalar @item_to_fragment_lines == 0) {
  warn 'Warning: there are 0 fragments under ', $article_dir, '.';
}

chomp @item_to_fragment_lines;

my %item_to_fragment_table = ();
my %fragment_to_item_table = ();

foreach my $item_to_fragment_line (@item_to_fragment_lines) {
  # Easy: each item comes from exactly one fragment
  (my $item, my $fragment) = split / => /, $item_to_fragment_line;
  $item_to_fragment_table{$item} = $fragment;

  # Less easy: some fragments (specifically, definition blocks)
  # generate multiple items
  my @generated_items;
  if (defined $fragment_to_item_table{$fragment}) {
    @generated_items = @{$fragment_to_item_table{$fragment}};
  } else {
    @generated_items = ();
  }
  push (@generated_items, $item);
  $fragment_to_item_table{$fragment} = \@generated_items;
}

sub resolve_item {
  my $item = shift;
  my $resolved;
  if ($item =~ /^ckb[0-9]+:/) {
    # We have some resolving to do
    $item =~ m/^ckb([0-9]+):([^:]+):/;
    (my $item_fragment_num, my $item_kind) = ($1, $2);
    unless (defined $item_fragment_num && defined $item_kind) {
      print "\n";
      die 'Error: we could not extract the fragment number and item kind from the string "', $item, '"';
    }
    my $item_fragment = "${article_basename}:fragment:${item_fragment_num}";
    if (defined $fragment_to_item_table{$item_fragment}) {
      my @generated_items = @{$fragment_to_item_table{$item_fragment}};
      if (scalar @generated_items == 0) {
        print "\n";
        die 'Error: somehow the entry in the fragment-to-item table for ', $item_fragment, ' is an empty list.', "\n";
      }
      if (scalar @generated_items == 1) {
        # Easy: the dependent fragment generated exactly one item;
        # $item depends on it
        $resolved = $generated_items[0];
      } else {
        # Less easy: the dependent item generated more than one
        # item; we need to find the one that is congruent with
        # $dep_fragment.
        my @candidate_items = grep (/:${item_kind}:/, @generated_items);
        if (scalar @candidate_items == 0) {
          print "\n";
          die 'Error: there are no candidate matches for ', $item_fragment, ' in the fragment-to-item table.', "\n";
        }
        if (scalar @candidate_items > 1) {
          print "\n";
          print STDERR ('Error: there are multiple candidate matches for ', $item_fragment, ' in the fragment-to-item table:');
          foreach my $candidate (@candidate_items) {
            print STDERR ('* ', $candidate, "\n");
          }
          die 'We require that there be exactly one.';
        }

        $resolved = $candidate_items[0];
      }
    } else {
      die 'Error: the fragment-to-item table does not contain ', $item, '.', "\n";
    }
  } else {
    $resolved = $item;
  }
  return $resolved;
}

my $dependencies_script = $script_paths{'dependencies.pl'};
foreach my $item (keys %item_to_fragment_table) {
  my $fragment = $item_to_fragment_table{$item};
  $fragment =~ m/^${article_basename}:fragment:([0-9]+)$/;
  my $fragment_number = $1;
  unless (defined $fragment_number) {
    die 'Error: we could not extract the article fragment number from the text', "\n", '  ', $fragment;
  }
  my $fragment_miz = "${article_dir}/text/ckb${fragment_number}.miz";
  unless (-e $fragment_miz) {
    die 'Error: the .miz file for fragment ', $fragment_number, ' of ', $article_basename, ' does not exist at the expected location (', $fragment_miz, ').';
  }
  my @fragment_dependencies = `$dependencies_script --stylesheet-home=${stylesheet_home} --script-home=${script_home} $fragment_miz 2> /dev/null`;
  (my $dependencies_exit_code, my $dependencies_message) = ($? >> 8, $!);
  if ($dependencies_exit_code != 0) {
    print STDERR ('Error: something went wrong when calling the dependencies script on fragment ', $fragment_number, ' of ', $article_basename, ';', "\n");
    print STDERR ('The exit code was ', $dependencies_exit_code, ' and the message was:', "\n");
    die $dependencies_message, "\n";
  }

  print $item;
  chomp @fragment_dependencies;
  if (scalar @fragment_dependencies > 0) {
    foreach my $dep (@fragment_dependencies) {
      my $resolved_dep = resolve_item ($dep);

      unless (defined $resolved_dep) {
        print "\n";
        die 'Error: we were unable to resolve the item ', $dep, '.';
      }

      # Special case: if we are computing the dependencies of a
      # pattern, then print only constructors and other
      # patterns.
      if ($item =~ /:.pattern:/) {
        if ($resolved_dep =~ /:.pattern:/ || $resolved_dep =~ /:.constructor:/) {
          print ' ', $resolved_dep;
        }
      } else {
        print ' ', $resolved_dep;
      }
    }
    print "\n";
  }
}

__END__

=head1 ITEMIZED-ARTICLE-DEPENDENCIES

itemized-article-dependencies.pl - Print the dependencies of an itemized Mizar article

=head1 SYNOPSIS

itemized-article-dependencies.pl [options] directory

Interpret the supplied directory as the result of itemizing a Mizar
article, and print the dependencies of each of the microarticles under
the supplied directory.

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose>

Say what we're doing as we're doing it.

=item B<--script-home=DIR>

The directory in which we will look for the needed auxiliary scripts.

=item B<--stylesheet-home=DIR>

The directory in which we will look for any needed auxiliary
stylesheets.

=back

=head1 DESCRIPTION

B<itemized-article-dependencies.pl> will consult the given article as
well as its environment to determine the article's dependencies, which
it prints (one per line) to standard output.

=head1 REQUIRED ARGUMENTS

It is necessary to supply a directory as the one and only argument of
this program.  The directory is supposed to be the result of itemizing
a Mizar article.  It should have the structure of a multi-article
Mizar development: there should be subdirectories 'prel', 'dict', and
'text'.

=head1 SEE ALSO

=over 8

=item F<dependencies.pl>

=item L<http://mizar.org/>

=back

=cut
