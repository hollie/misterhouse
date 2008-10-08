cd ..\docs

call pod2html mh.pod > mh.html
call pod2text mh.pod > mh.txt

call pod2html install.pod > install.html
call pod2text install.pod > install.txt

call pod2html faq.pod > faq.html
call pod2text faq.pod > faq.txt

call pod2html faq_frs.pod > faq_frs.html
call pod2text faq_frs.pod > faq_frs.txt

call pod2html faq_ia.pod > faq_ia.html
call pod2text faq_ia.pod > faq_ia.txt

call pod2text faq_mhmedia.pod > faq_mhmedia.txt
call pod2html faq_mhmedia.pod > faq_mhmedia.html

call pod2html updates.pod > updates.html
call pod2text updates.pod > updates.txt

perl ..\bin\authors updates.pod > authors.html

@rem copy \data\mh_usage.txt .
@rem perl ..\bin\mh_users_table.pl mh_usage.txt > mh_usage_table.html
