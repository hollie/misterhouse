#!/usr/bin/perl -w

use strict;
use lib "..";
use Insteon::MessageDecoder;

#0250 1e5d8e 1edc30 2b 0d02
plm_decode_print('02525700');
plm_decode_print('02525a80');
plm_decode_print('02530102aabbcc1a1bff');
plm_decode_print('025402');
plm_decode_print('02560105aabbcc');
plm_decode_print('0257ff04aabbcc0badff');
plm_decode_print('025806');
plm_decode_print('025a15aabbcc');
plm_decode_print('0260');
plm_decode_print('02601edc3003159b06');
plm_decode_print('026105eeff');
plm_decode_print('026105eeff06');
plm_decode_print('02635700');
plm_decode_print('0263570006');
plm_decode_print('02635a80');
plm_decode_print('02635a8006');
plm_decode_print('02640105');
plm_decode_print('02640305');
plm_decode_print('0264000506');
plm_decode_print('0264ff05');
plm_decode_print('0265');
plm_decode_print('026515');
plm_decode_print('026603159b');
plm_decode_print('026603159b06');
plm_decode_print('0267');
plm_decode_print('026706');
plm_decode_print('0268bb');
plm_decode_print('0268bb06');
plm_decode_print('0269');
plm_decode_print('026915');
plm_decode_print('026a');
plm_decode_print('026a06');
plm_decode_print('026bf0');
plm_decode_print('026bf006');
plm_decode_print('026b00');
plm_decode_print('026c');
plm_decode_print('026c06');
plm_decode_print('026d');
plm_decode_print('026d15');
plm_decode_print('026e');
plm_decode_print('026e06');
plm_decode_print('026f20ff05aabbcc0badff');
plm_decode_print('026f41ff05aabbcc0badff15');
plm_decode_print('0270bb');
plm_decode_print('0270bb06');
plm_decode_print('02710bad');
plm_decode_print('02710bad06');
plm_decode_print('0272');
plm_decode_print('027206');
plm_decode_print('0273f00000');
plm_decode_print('0273f0000006');
plm_decode_print('0273000000');
plm_decode_print('0274000000');

plm_decode_print('02621e5d8e0f0d00');
plm_decode_print('02621e5d8e2f0d00');
plm_decode_print('02621e5d8e4f0d00');
plm_decode_print('02621e5d8e6f0d00');
plm_decode_print('02621e5d8e8f0d00');
plm_decode_print('02621e5d8eaf0d00');
plm_decode_print('02621e5d8ecf0d00');
plm_decode_print('02621e5d8eef0d00');

plm_decode_print('02621e5d8e0f0d0006');
plm_decode_print('02621e5d8e0f0f00');
plm_decode_print('02501e5d8e1edc302b0f00');

plm_decode_print('02622042d30f1f00');
plm_decode_print('02501e5d8e1edc302b1f00');

plm_decode_print('02502042d3000005cb1100');
plm_decode_print('02502042d3110105cb0600');

plm_decode_print('02621f058c1f2e000100000000000000000000000000');
plm_decode_print('02511f058c1edc30112e000101000020201cfe3f0001000000');

sub plm_decode_print {
    my ($plm_string) = @_;
    print("PLM Message: $plm_string\n");
    print( Insteon::MessageDecoder::plm_decode($plm_string) . "\n" );
}
