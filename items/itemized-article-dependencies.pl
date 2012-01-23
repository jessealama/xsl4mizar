#!/usr/bin/perl

use warnings;
use strict;
use File::Basename qw(basename);
use Getopt::Long;
use Pod::Usage;
use File::Temp qw(tempfile);
use Carp qw(croak carp);
use XML::LibXML;
use Memoize qw(memoize);

# Set up an XML parser that we might use
my $xml_parser = XML::LibXML->new ();

sub ensure_valid_xml_file {
  my $xml_path = shift;
  ensure_readable_file ($xml_path);
  if (defined eval { $xml_parser->parse_file ($xml_path) }) {
    return 1;
  } else {
    croak ('Error: ', $xml_path, ' is not a well-formed XML file.');
  }
}

sub ensure_readable_file {
  my $file = shift;

  if (! -e $file) {
    croak ('Error: ', $file, ' does not exist.');
  }
  if (! -f $file) {
    croak ('Error: ', $file, ' is not a file.');
  }

  if (! -r $file) {
    croak ('Error: ', $file, ' is unreadable.');
  }

  return 1;
}

sub tmpfile_path {
  # File::Temp's tempfile function returns a list of two values.  We
  # want the second (the path of the temprary file) and don't care
  # about the first (a filehandle for the temporary file).  See
  # http://search.cpan.org/~tjenness/File-Temp-0.22/Temp.pm for more
  (undef, my $path) = eval { tempfile (); };
  my $tempfile_err = $@;
  if (defined $path) {
    return $path;
  } else {
    croak ('Error: we could not create a temporary file!  The error message was:', "\n", "\n", '  ', $tempfile_err);
  }
}

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
    croak ('Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets does not exist.');
  }
  if (! -d $stylesheet_home) {
    croak ('Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.');
  }
} else {
  $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';
  if (! -e $stylesheet_home) {
    croak ('Error: the default directory in which we look for stylesheets', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'does not exist.  Consider using the --stylesheet-home option.');
  }
  if (! -d $stylesheet_home) {
    croak ('Error: the default directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.  Consider using the --stylesheet-home option.');
  }
}

if (defined $script_home) {
  if (! -e $script_home) {
    croak ('Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for needed auxiliary scripts does not exist.');
  }
  if (! -d $script_home) {
    croak ('Error: the supplied directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for needed auxiliary is not actually a directory.');
  }
} else {
  $script_home = '/Users/alama/sources/mizar/xsl4mizar/items';
  if (! -e $script_home) {
    croak ('Error: the default directory in which we look for needed auxiliary scripts', "\n", "\n", '  ', $script_home, "\n", "\n", 'does not exist.  Consider using the --script-home option.');
  }
  if (! -d $script_home) {
    croak ('Error: the default directory', "\n", "\n", '  ', $script_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.  Consider using the --script-home option.');
  }
}

my $article_dir = $ARGV[0];

unless (-d $article_dir) {
  croak ('Error: ', $article_dir, ' is not a directory.');
}

my $article_basename = basename ($article_dir);

my %script_paths = ('map-ckbs.pl' => "${script_home}/map-ckbs.pl",
		    'dependencies.pl' => "${script_home}/dependencies.pl");

foreach my $script (keys %script_paths) {
  my $script_path = $script_paths{$script};
  if (! -e $script_path) {
    croak ('Error: the needed auxiliary script', "\n", "\n", '  ', $script, "\n", "\n", 'does not exist at the expected location', "\n", "\n", '  ', $script_path);
  }
  if (! -r $script_path) {
    croak ('Error: the needed auxiliary script', "\n", "\n", '  ', $script, "\n", "\n", 'at', "\n", "\n", '  ', $script_path, "\n", "\n", 'is unreadable.');
  }
  if (! -x $script_path) {
    croak ('Error: the needed auxiliary script', "\n", "\n", '  ', $script, 'at', "\n", "\n", '  ', $script_path, 'is not executable.');
  }
}

my $map_ckb_script = $script_paths{'map-ckbs.pl'};
my $map_ckb_err_file = tmpfile_path ();
my @item_to_fragment_lines = `$map_ckb_script $article_dir 2> $map_ckb_err_file`;

my $item_to_fragment_exit_code = $? >> 8;
if ($item_to_fragment_exit_code != 0) {
  if (-z $map_ckb_err_file) {
    croak ('Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", '(Curiously, the map-ckb script did not produce any error output.)');
  } elsif (! -r $map_ckb_err_file) {
    croak ('Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", '(Curiously, we are unable to read the error output file of the map-ckb script.)');
  } else {
    print STDERR ('Error: something went wrong computing the item-to-fragment table; the exit code was ', $item_to_fragment_exit_code, '.', "\n", 'Here is the error output produced by the map-ckb script:', "\n");
    print '----------------------------------------------------------------------', "\n";
    system ('cat', $map_ckb_err_file);
    print '----------------------------------------------------------------------', "\n";
    croak;
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

  # my $fragment = undef;

  # if ($maybe_pseudo_fragment =~ / ([a-z0-9_]+) : ([^:]+) : ([0-9]+) \[ [a-z]{2} \] \z/x) {
  #   $fragment = "${1}:${2}:${3}";
  #   # DEBUG
  #   warn 'pseudo-fragment ', $maybe_pseudo_fragment, ' comes from ', $fragment, '.';
  # } else {
  #   # This isn't a pseudo fragment after all
  #   $fragment = $maybe_pseudo_fragment;
  # }

  $item_to_fragment_table{$item} = $fragment;
  $fragment_to_item_table{$fragment} = $item;

  # # Less easy: some fragments (specifically, definition blocks)
  # # generate multiple items
  # my @generated_items;
  # if (defined $fragment_to_item_table{$fragment}) {
  #   @generated_items = @{$fragment_to_item_table{$fragment}};
  # } else {
  #   @generated_items = ();
  # }
  # push (@generated_items, $item);
  # $fragment_to_item_table{$fragment} = \@generated_items;
}

# DEBUG: print out the table
# foreach my $fragment (keys %fragment_to_item_table) {
#   my @deps = @{$fragment_to_item_table{$fragment}};
#   # warn $fragment, ' generated ', join (' ', @deps);
# }

memoize ('resolve_item');
sub resolve_item {
  my $item = shift;

  if ($item =~ /\A ckb ([0-9]+) : ([^:]+) : [0-9]+ /x) {
    (my $item_fragment_num, my $item_kind) = ($1, $2);

    my $item_fragment = undef;

    if ($item =~ / (.) pattern : /x) {
      my $pattern_kind = $1;
      $item_fragment = "${article_basename}:fragment:${item_fragment_num}[${pattern_kind}p]";
    } elsif ($item =~ / (.) definiens /x) {
      my $definiens_kind = $1;
      $item_fragment = "${article_basename}:fragment:${item_fragment_num}[${definiens_kind}f]";
    } elsif ($item =~ / deftheorem /x) {
      $item_fragment = "${article_basename}:fragment:${item_fragment_num}[dt]";
    } elsif ($item =~ / \[ existence \] /x ) {
      $item_fragment = "${article_basename}:fragment:${item_fragment_num}[ex]";
    } elsif ($item =~ / (.) constructor /x) {
      my $constructor_kind = $1;
      $item_fragment = "${article_basename}:fragment:${item_fragment_num}[${constructor_kind}c]";
    } else {
      $item_fragment = "${article_basename}:fragment:${item_fragment_num}";
    }

    if (defined $fragment_to_item_table{$item_fragment}) {

      return $fragment_to_item_table{$item_fragment};

    } else {
      croak ('Error: the fragment-to-item table does not contain ', $item_fragment, '.', "\n", 'The keys of the fragment-to-item table are:', "\n", join ("\n", keys %fragment_to_item_table), "\n");
    }
  } else {
    return $item;
  }
}

my %conditions_and_properties_shortcuts
  = ('existence' => 'ex',
     'uniqueness' => 'un',
     'coherence' => 'ch',
     'correctness' => 'cr',
     'abstractness' => 'ab',
     'reflexivity' => 're',
     'irreflexivity' => 'ir',
     'symmetry' => 'sy',
     'asymmetry' => 'as',
     'connectedness' => 'cn',
     'involutiveness' => 'in',
     'projectivity' => 'pr',
     'idempotence' => 'id',
     'commutativity' => 'cm',
     'compatibility' => 'cp',
     'sethood' => 'se',
     'pattern' => 'pa');

my %full_name_of_shortcut = ();
foreach my $long_name (keys %conditions_and_properties_shortcuts) {
  my $shortcut = $conditions_and_properties_shortcuts{$long_name};
  $full_name_of_shortcut{$shortcut} = $long_name;
}

my $dependencies_script = $script_paths{'dependencies.pl'};
foreach my $item (keys %item_to_fragment_table) {
  my %item_deps = ();
  if ($item =~ /\A ([a-z0-9_]+) : ([^:]+) : ([0-9]+) /x) {
    (my $item_article, my $item_kind, my $item_number) = ($1, $2, $3);
    my $fragment = $item_to_fragment_table{$item};

    if ($fragment =~ m/\A ${article_basename} : fragment : ([0-9]+) /x) {
      my $fragment_number = $1;
      my $fragment_miz = undef;

      # Resolve properties and correctness conditions
      if ($fragment =~ / \[ ([a-z]+) \] \z /x) {
	my $property_or_condition_code = $1;
	$fragment_miz = "${article_dir}/text/ckb${fragment_number}${property_or_condition_code}.miz";
      } elsif ($item =~ / : (.) constructor [0-9]+ \z /x) {
	my $constructor_kind = $1;
	$fragment_miz = "${article_dir}/text/ckb${fragment_number}${constructor_kind}c.miz";
      } else {
	$fragment_miz = "${article_dir}/text/ckb${fragment_number}.miz";
      }

      if (-e $fragment_miz) {
	my $dependencies_err = tmpfile_path ();
	my @fragment_dependencies = `$dependencies_script --stylesheet-home=${stylesheet_home} $fragment_miz 2> $dependencies_err`;

	my $dependencies_exit_code = $? >> 8;
	if ($dependencies_exit_code != 0) {
	  my $dependencies_message = `cat $dependencies_err`;
	  print STDERR ('Error: something went wrong when calling the dependencies script on fragment ', $fragment_number, ' of ', $article_basename, ';', "\n");
	  print STDERR ('The exit code was ', $dependencies_exit_code, ' and the message was:', "\n");
	  croak ($dependencies_message);
	}

	chomp @fragment_dependencies;
	if (scalar @fragment_dependencies > 0) {
	  foreach my $dep (@fragment_dependencies) {
	    my $resolved_dep = eval { resolve_item ($dep); };
	    my $resolve_err = $@;
	    if (! defined $resolved_dep) {
	      croak ('Error: we were unable to resolve the dependency ', $dep, ' of the item ', $item, '.', "\n", 'The reported error was:', "\n", $resolve_err);
	    }
	    $item_deps{$resolved_dep} = 0;

 	    # Ensure that items that depend on functor constructors
	    # depend directly on the corresponding existence and
	    # uniqueness items for the constructor.

	    if ($resolved_dep =~ / : kconstructor : [0-9]+ \z /x) {
	      my $existence_item = "${resolved_dep}[existence]";
	      my $uniqueness_item = "${resolved_dep}[uniqueness]";
	      $item_deps{$existence_item} = 0;
	      $item_deps{$uniqueness_item} = 0;
	    }

	  }
	}

      } else {
	croak ('Error: we cannot determine the dependencies of ', $item, ' because the fragment to which it corresponds, ', $fragment_miz, ', does not exist.');
      }

      # Now print the dependencies
      print $item;
      foreach my $dep (keys %item_deps) {
	print ' ', $dep;
      }
      print "\n";

    } else {
      croak ('Error: we could not extract the article fragment number from the text', "\n", '  ', $fragment);
    }
  } else {
    croak ('Error: we cannot make sense of the item \'', $item, '\'.', "\n");
  }
}

# Esnure that function constructors that lack existence and uniqueness
# conditions, but do have a coherence condition, generate existence
# and uniqueness items that depend on the constructor

foreach my $item (keys %item_to_fragment_table) {
  if ($item =~ / : kconstructor : [0-9]+ \z /x ) {
    my $existence_condition = "${item}[existence]";
    my $uniqueness_condition = "${item}[uniqueness]";
    if (! defined $item_to_fragment_table{$existence_condition}
      && ! defined $item_to_fragment_table{$uniqueness_condition}) {
      my $coherence_condition = "${item}[coherence]";
      if (defined $item_to_fragment_table{$coherence_condition}) {
	print $existence_condition, ' ', $coherence_condition, "\n";
	print $uniqueness_condition, ' ', $coherence_condition, "\n";
      } else {
	croak ('Error: the function constructor ', $item, ' lacks known existence and uniqueness conditions, as well as a known coherence condition.', "\n");
      }
    }
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
