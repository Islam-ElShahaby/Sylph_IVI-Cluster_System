#ifndef RADIOSTATIONSMODEL_H
#define RADIOSTATIONSMODEL_H

#include <QAbstractListModel>
#include <QString>
#include <QVector>

struct RadioStation {
    QString stationId;
    QString name;
    QString streamUrl;
    QString favicon;
    QString tags;
    QString country;
    QString language;
    QString codec;
    int bitrate = 0;
};

class RadioStationsModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum StationRole {
        StationIdRole = Qt::UserRole + 1,
        NameRole,
        StreamUrlRole,
        FaviconRole,
        TagsRole,
        CountryRole,
        LanguageRole,
        CodecRole,
        BitrateRole
    };

    explicit RadioStationsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setStations(const QVector<RadioStation> &stations);
    const RadioStation *stationAt(int index) const;
    void clear();

private:
    QVector<RadioStation> m_stations;
};

#endif // RADIOSTATIONSMODEL_H
