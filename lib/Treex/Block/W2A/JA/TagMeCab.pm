package Treex::Block::W2A::JA::TagMeCab;
$Treex::Block::W2A::JA::TagMeCab::VERSION = '0.13095';
use strict;
use warnings;

use Moose;
use Encode;
use Treex::Core::Common;
use Treex::Tool::Tagger::MeCab;

extends 'Treex::Core::Block';

has _form_corrections => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    default => sub {
        {
            q(``) => q("),
            q('') => q("),
        }
    },
    documentation => q{Possible changes in forms done by tagger},
);

has tagger => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    return;
}

sub process_start {
    my ($self) = @_;

    my $tagger = Treex::Tool::Tagger::MeCab->new(); 
    $self->set_tagger( $tagger );
    
    return;   
} 

sub process_zone {


    my ( $self, $zone ) = @_;

    # get the source sentence
    my $sentence = $zone->sentence;
    log_fatal("No sentence in zone") if !defined $sentence;
    log_fatal(qq{There's already atree in zone}) if $zone->has_atree();
    log_debug("Processing sentence: $sentence"); 

    my $result = "";

    my $debug = "";
    
    my ( @tokens ) = $self->tagger->process_sentence( $sentence );

    # modifies the output format of MeCab wrapper
    foreach my $token ( @tokens ) {
    	my @features = split /\t/, $token;
        my $wordform = $features[0];

        my $bTag = $features[1].'-'.$features[2].'-'.$features[3].'-'.$features[4];
        my $lemma = $features[7];      

    	if ($bTag !~ "BOS" && $bTag !~ "空白") {
            
            $lemma = $wordform if $lemma =~ m/\*/;
            $bTag =~ s{^(.+)$}{<$1>};
            my $eTag = $bTag;
            $eTag =~ s{<}{</};

	    $result .= ' '.$bTag.$wordform.$eTag.$lemma;
            
    	}
    }
    $result =~ s{^\s+}{};

    # split on whitespace, tags nor tokens doesn't contain spaces
    my @tagged = split /\s+/,  $result;

    # create a-tree
    my $a_root    = $zone->create_atree();
    my $tag_regex = qr{
        <([^\-]+\-[^\-]+\-[^\-]+\-[^\-]+)> #<tag>
        ([^<]+) #form
        </\1>   #</tag>
        (.+)    #lemma
        }x;
    my $space_start = qr{^\s+};
    my $ord         = 1;
    foreach my $tag_pair (@tagged) {
        if ( $tag_pair =~ $tag_regex ) {
            my $form = $2;
            
            my $tag = $1; 
            $tag =~ s{^<(\w+)>.$}{$1};

            my $lemma = $3;

            $debug .= "$form   $tag;    ";
 
            if ( $sentence =~ s/^\Q$form\E// ) {

                # check if there is space after word
                my $no_space_after = $sentence =~ m/$space_start/ ? 0 : 1;
                if ( $sentence eq q{} ) {
                    $no_space_after = 0;
                }

                # delete it
                $sentence =~ s{$space_start}{};
		
                # and create node under root
                $a_root->create_child(
                    form           => $form,
                    tag            => $tag,
                    lemma          => $lemma,
                    no_space_after => $no_space_after,
                    ord            => $ord++,
                );
            }
            else {
                log_fatal("Mismatch between tagged word and original sentence: Tagged: $form; $debug.  Original: $sentence.");
            }
        }
        else {
            log_fatal("Incorrect output format from MeCab: $tag_pair debug: $debug");
        }

    }
    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::TagMeCab

=head1 VERSION

version 0.13095

=head1 DESCRIPTION

Each sentence is tokenized and tagged using C<MeCab> (Ipadic POS tags).
Ipadic tagset uses hierarchical tags. There are four levels of hierarchy,
each level is separated by "-". Empty kategories are marked as "*".
Tags are in kanji, in the future they should be replaced by Romanized tags or their abbreviations (other japanese treex modules should be modified accordingly).

=head1 SEE ALSO

L<MeCab Home Page|http://mecab.googlecode.com/svn/trunk/mecab/doc/index.html>

=cut
