
# Return the current Mr.House status button,
# and cycle them when users click on it.
# Is being called from modes/main.shtml.

# Authority: anyone

return
  "<a href='/RUN;&referer(/ia5/modes/main.shtml)?Toggle_the_house_mode'><img src=images/$Save{mode}.gif alt='Mode $Save{mode}' border=0></a>";
