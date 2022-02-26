function Meta (meta)
  if pandoc.utils.type(meta.title) == 'Inlines' then
    meta.title = meta.title:walk {
      Space = function () return pandoc.LineBreak() end
    }
  end
  return meta
end
